package nixgen.crypto;

import org.bouncycastle.crypto.generators.Ed25519KeyPairGenerator;
import org.bouncycastle.crypto.params.Ed25519KeyGenerationParameters;
import org.bouncycastle.crypto.params.Ed25519PrivateKeyParameters;
import org.bouncycastle.crypto.params.Ed25519PublicKeyParameters;
import org.bouncycastle.crypto.AsymmetricCipherKeyPair;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * Generates Ed25519 SSH host keys in OpenSSH format.
 */
public class Ed25519KeyGen {
    private byte[] privateKey;
    private byte[] publicKey;
    private byte[] seed;

    public Ed25519KeyGen() {
        generateKeyPair();
    }

    private void generateKeyPair() {
        SecureRandom random = new SecureRandom();
        Ed25519KeyPairGenerator keyPairGenerator = new Ed25519KeyPairGenerator();
        keyPairGenerator.init(new Ed25519KeyGenerationParameters(random));

        AsymmetricCipherKeyPair keyPair = keyPairGenerator.generateKeyPair();

        Ed25519PrivateKeyParameters privParams = (Ed25519PrivateKeyParameters) keyPair.getPrivate();
        Ed25519PublicKeyParameters pubParams = (Ed25519PublicKeyParameters) keyPair.getPublic();

        this.publicKey = pubParams.getEncoded();
        this.seed = privParams.getEncoded();
        // Ed25519 private key is seed || public key
        this.privateKey = new byte[64];
        System.arraycopy(seed, 0, privateKey, 0, 32);
        System.arraycopy(publicKey, 0, privateKey, 32, 32);
    }

    /**
     * Get the raw 32-byte Ed25519 public key.
     */
    public byte[] getPublicKeyBytes() {
        return publicKey.clone();
    }

    /**
     * Get the raw 32-byte seed (private key portion).
     */
    public byte[] getSeedBytes() {
        return seed.clone();
    }

    /**
     * Get the public key in OpenSSH authorized_keys format.
     */
    public String getPublicKeyOpenSSH(String comment) {
        try {
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            DataOutputStream dos = new DataOutputStream(baos);

            byte[] keyType = "ssh-ed25519".getBytes(StandardCharsets.UTF_8);
            dos.writeInt(keyType.length);
            dos.write(keyType);
            dos.writeInt(publicKey.length);
            dos.write(publicKey);
            dos.close();

            String base64Key = Base64.getEncoder().encodeToString(baos.toByteArray());
            if (comment != null && !comment.isEmpty()) {
                return "ssh-ed25519 " + base64Key + " " + comment;
            }
            return "ssh-ed25519 " + base64Key;
        } catch (Exception e) {
            throw new RuntimeException("Failed to generate OpenSSH public key", e);
        }
    }

    /**
     * Get the private key in OpenSSH format (PEM-like).
     */
    public String getPrivateKeyOpenSSH() {
        try {
            SecureRandom random = new SecureRandom();
            byte[] checkInt = new byte[4];
            random.nextBytes(checkInt);

            ByteArrayOutputStream privSection = new ByteArrayOutputStream();
            DataOutputStream privDos = new DataOutputStream(privSection);

            // Check integers (must match for integrity)
            privDos.write(checkInt);
            privDos.write(checkInt);

            // Key type
            byte[] keyType = "ssh-ed25519".getBytes(StandardCharsets.UTF_8);
            privDos.writeInt(keyType.length);
            privDos.write(keyType);

            // Public key
            privDos.writeInt(publicKey.length);
            privDos.write(publicKey);

            // Private key (64 bytes: seed || public)
            privDos.writeInt(64);
            privDos.write(seed);
            privDos.write(publicKey);

            // Empty comment
            privDos.writeInt(0);

            // Padding to block size (8 bytes for none cipher)
            int blockSize = 8;
            int padLen = blockSize - (privSection.size() % blockSize);
            if (padLen == blockSize) padLen = 0;
            for (int i = 1; i <= padLen; i++) {
                privDos.writeByte(i);
            }
            privDos.close();

            // Build full key blob
            ByteArrayOutputStream fullKey = new ByteArrayOutputStream();
            DataOutputStream fullDos = new DataOutputStream(fullKey);

            // Auth magic
            fullDos.write("openssh-key-v1".getBytes(StandardCharsets.UTF_8));
            fullDos.writeByte(0); // null terminator

            // Cipher name: none
            byte[] cipherName = "none".getBytes(StandardCharsets.UTF_8);
            fullDos.writeInt(cipherName.length);
            fullDos.write(cipherName);

            // KDF name: none
            byte[] kdfName = "none".getBytes(StandardCharsets.UTF_8);
            fullDos.writeInt(kdfName.length);
            fullDos.write(kdfName);

            // KDF options: empty
            fullDos.writeInt(0);

            // Number of keys
            fullDos.writeInt(1);

            // Public key blob
            ByteArrayOutputStream pubBlob = new ByteArrayOutputStream();
            DataOutputStream pubDos = new DataOutputStream(pubBlob);
            pubDos.writeInt(keyType.length);
            pubDos.write(keyType);
            pubDos.writeInt(publicKey.length);
            pubDos.write(publicKey);
            pubDos.close();

            byte[] pubBlobBytes = pubBlob.toByteArray();
            fullDos.writeInt(pubBlobBytes.length);
            fullDos.write(pubBlobBytes);

            // Private key section
            byte[] privSectionBytes = privSection.toByteArray();
            fullDos.writeInt(privSectionBytes.length);
            fullDos.write(privSectionBytes);
            fullDos.close();

            // Base64 encode with line wrapping
            String base64 = Base64.getEncoder().encodeToString(fullKey.toByteArray());
            StringBuilder sb = new StringBuilder();
            sb.append("-----BEGIN OPENSSH PRIVATE KEY-----\n");
            for (int i = 0; i < base64.length(); i += 70) {
                sb.append(base64, i, Math.min(i + 70, base64.length()));
                sb.append("\n");
            }
            sb.append("-----END OPENSSH PRIVATE KEY-----\n");
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Failed to generate OpenSSH private key", e);
        }
    }
}
