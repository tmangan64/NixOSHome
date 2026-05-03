package nixgen.crypto;

import org.bouncycastle.math.ec.rfc7748.X25519;
import org.bouncycastle.math.ec.rfc8032.Ed25519;
import org.bouncycastle.crypto.digests.SHA512Digest;

import java.math.BigInteger;
import java.util.Arrays;

/**
 * Converts Ed25519 SSH keys to X25519 age keys.
 * This is the standard cryptographic conversion used by ssh-to-age.
 */
public class SshToAge {

    // Ed25519 curve order
    private static final BigInteger L = new BigInteger(
        "7237005577332262213973186563042994240857116359379907606001950938285454250989"
    );

    /**
     * Convert Ed25519 private key (seed) to X25519 private key.
     */
    public static byte[] convertPrivateKey(byte[] ed25519Seed) {
        // Hash the seed with SHA-512 (same as Ed25519 key derivation)
        SHA512Digest sha512 = new SHA512Digest();
        byte[] hash = new byte[64];
        sha512.update(ed25519Seed, 0, ed25519Seed.length);
        sha512.doFinal(hash, 0);

        // Clamp the first 32 bytes for X25519
        byte[] x25519Private = Arrays.copyOf(hash, 32);
        x25519Private[0] &= 248;
        x25519Private[31] &= 127;
        x25519Private[31] |= 64;

        return x25519Private;
    }

    /**
     * Convert Ed25519 public key to X25519 public key.
     * Uses the birational map from Edwards to Montgomery form.
     */
    public static byte[] convertPublicKey(byte[] ed25519Public) {
        // Ed25519 public key is a point on the Edwards curve
        // y-coordinate is stored directly (little-endian, high bit is sign of x)

        // Extract y coordinate (clear sign bit)
        byte[] yBytes = ed25519Public.clone();
        yBytes[31] &= 0x7f;

        // Convert y to BigInteger (little-endian)
        byte[] yBytesReversed = new byte[32];
        for (int i = 0; i < 32; i++) {
            yBytesReversed[i] = yBytes[31 - i];
        }
        BigInteger y = new BigInteger(1, yBytesReversed);

        // Field prime p = 2^255 - 19
        BigInteger p = BigInteger.valueOf(2).pow(255).subtract(BigInteger.valueOf(19));

        // u = (1 + y) / (1 - y) mod p
        BigInteger one = BigInteger.ONE;
        BigInteger numerator = one.add(y).mod(p);
        BigInteger denominator = one.subtract(y).mod(p);
        BigInteger u = numerator.multiply(denominator.modInverse(p)).mod(p);

        // Convert u back to little-endian 32 bytes
        byte[] uBytesRaw = u.toByteArray();
        byte[] x25519Public = new byte[32];

        // Handle BigInteger's sign byte and convert to little-endian
        int offset = uBytesRaw.length > 32 ? uBytesRaw.length - 32 : 0;
        int len = Math.min(uBytesRaw.length, 32);
        for (int i = 0; i < len; i++) {
            x25519Public[i] = uBytesRaw[uBytesRaw.length - 1 - i - offset + (uBytesRaw.length > 32 ? 0 : 0)];
        }

        // Proper conversion from big-endian BigInteger to little-endian bytes
        x25519Public = new byte[32];
        if (uBytesRaw[0] == 0 && uBytesRaw.length > 1) {
            // Remove leading zero byte from BigInteger
            uBytesRaw = Arrays.copyOfRange(uBytesRaw, 1, uBytesRaw.length);
        }
        for (int i = 0; i < uBytesRaw.length && i < 32; i++) {
            x25519Public[i] = uBytesRaw[uBytesRaw.length - 1 - i];
        }

        return x25519Public;
    }

    /**
     * Get age public key from Ed25519 public key.
     */
    public static String getAgePublicKeyFromEd25519Public(byte[] ed25519Public) {
        byte[] x25519Public = convertPublicKey(ed25519Public);
        return Bech32.encode("age1", x25519Public);
    }

    /**
     * Get age private key from Ed25519 seed.
     */
    public static String getAgePrivateKeyFromEd25519Seed(byte[] ed25519Seed) {
        byte[] x25519Private = convertPrivateKey(ed25519Seed);
        String bech32 = Bech32.encode("age-secret-key-1", x25519Private);
        return bech32.toUpperCase();
    }
}
