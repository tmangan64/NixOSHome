package nixgen.crypto;

import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;

/**
 * SHA-512 crypt password hashing compatible with mkpasswd -m sha-512.
 * Implements the SHA-512-crypt algorithm as specified in:
 * https://www.akkadia.org/drepper/SHA-crypt.txt
 */
public class Sha512Crypt {
    private static final String SALT_CHARS =
        "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    private static final int SALT_LEN = 16;
    private static final int ROUNDS_DEFAULT = 5000;

    /**
     * Hash a password using SHA-512 crypt with a random salt.
     */
    public static String hash(String password) {
        String salt = generateSalt();
        return hash(password, salt);
    }

    /**
     * Hash a password using SHA-512 crypt with the specified salt.
     */
    public static String hash(String password, String salt) {
        return sha512Crypt(password.getBytes(), salt, ROUNDS_DEFAULT);
    }

    private static String generateSalt() {
        SecureRandom random = new SecureRandom();
        StringBuilder salt = new StringBuilder(SALT_LEN);
        for (int i = 0; i < SALT_LEN; i++) {
            salt.append(SALT_CHARS.charAt(random.nextInt(SALT_CHARS.length())));
        }
        return salt.toString();
    }

    private static String sha512Crypt(byte[] password, String salt, int rounds) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-512");
            byte[] saltBytes = salt.getBytes("UTF-8");

            // Step 1-8: Compute digest B
            md.reset();
            md.update(password);
            md.update(saltBytes);
            md.update(password);
            byte[] digestB = md.digest();

            // Step 9-12: Compute digest A
            md.reset();
            md.update(password);
            md.update(saltBytes);

            // Step 11: Add digestB repeatedly
            int keyLen = password.length;
            for (int i = keyLen; i > 64; i -= 64) {
                md.update(digestB);
            }
            md.update(digestB, 0, keyLen % 64 == 0 ? 64 : keyLen % 64);

            // Step 12: Add bits based on key length
            for (int i = keyLen; i > 0; i >>= 1) {
                if ((i & 1) != 0) {
                    md.update(digestB);
                } else {
                    md.update(password);
                }
            }
            byte[] digestA = md.digest();

            // Step 13-15: Compute DP
            md.reset();
            for (int i = 0; i < keyLen; i++) {
                md.update(password);
            }
            byte[] dpFull = md.digest();
            byte[] dp = new byte[keyLen];
            for (int i = 0; i < keyLen; i++) {
                dp[i] = dpFull[i % 64];
            }

            // Step 16-18: Compute DS
            md.reset();
            for (int i = 0; i < 16 + (digestA[0] & 0xff); i++) {
                md.update(saltBytes);
            }
            byte[] dsFull = md.digest();
            byte[] ds = new byte[saltBytes.length];
            for (int i = 0; i < saltBytes.length; i++) {
                ds[i] = dsFull[i % 64];
            }

            // Step 19-20: Rounds
            byte[] digest = digestA;
            for (int round = 0; round < rounds; round++) {
                md.reset();

                if ((round & 1) != 0) {
                    md.update(dp);
                } else {
                    md.update(digest);
                }

                if (round % 3 != 0) {
                    md.update(ds);
                }

                if (round % 7 != 0) {
                    md.update(dp);
                }

                if ((round & 1) != 0) {
                    md.update(digest);
                } else {
                    md.update(dp);
                }

                digest = md.digest();
            }

            // Encode the result
            String hash = b64Encode(digest);

            if (rounds == ROUNDS_DEFAULT) {
                return "$6$" + salt + "$" + hash;
            } else {
                return "$6$rounds=" + rounds + "$" + salt + "$" + hash;
            }

        } catch (Exception e) {
            throw new RuntimeException("Failed to compute SHA-512 crypt", e);
        }
    }

    private static String b64Encode(byte[] digest) {
        // SHA-512 crypt uses a specific permutation and base64 encoding
        int[] permutation = {
            42, 21, 0, 1, 43, 22, 23, 2, 44, 45, 24, 3, 4, 46, 25, 26, 5, 47,
            48, 27, 6, 7, 49, 28, 29, 8, 50, 51, 30, 9, 10, 52, 31, 32, 11, 53,
            54, 33, 12, 13, 55, 34, 35, 14, 56, 57, 36, 15, 16, 58, 37, 38, 17, 59,
            60, 39, 18, 19, 61, 40, 41, 20, 62, 63
        };

        StringBuilder result = new StringBuilder();

        // Process 3 bytes at a time
        for (int i = 0; i < 63; i += 3) {
            int b0 = digest[permutation[i]] & 0xff;
            int b1 = digest[permutation[i + 1]] & 0xff;
            int b2 = digest[permutation[i + 2]] & 0xff;

            int value = b0 | (b1 << 8) | (b2 << 16);

            result.append(SALT_CHARS.charAt(value & 0x3f));
            result.append(SALT_CHARS.charAt((value >> 6) & 0x3f));
            result.append(SALT_CHARS.charAt((value >> 12) & 0x3f));
            result.append(SALT_CHARS.charAt((value >> 18) & 0x3f));
        }

        // Handle last byte (index 63)
        int last = digest[permutation[63]] & 0xff;
        result.append(SALT_CHARS.charAt(last & 0x3f));
        result.append(SALT_CHARS.charAt((last >> 6) & 0x3f));

        return result.toString();
    }
}
