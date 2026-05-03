package nixgen.crypto;

import org.bouncycastle.crypto.generators.X25519KeyPairGenerator;
import org.bouncycastle.crypto.params.X25519KeyGenerationParameters;
import org.bouncycastle.crypto.params.X25519PrivateKeyParameters;
import org.bouncycastle.crypto.params.X25519PublicKeyParameters;
import org.bouncycastle.crypto.AsymmetricCipherKeyPair;

import java.security.SecureRandom;

/**
 * Generates X25519 key pairs for age encryption.
 */
public class X25519KeyGen {
    private byte[] privateKey;
    private byte[] publicKey;

    public X25519KeyGen() {
        generateKeyPair();
    }

    /**
     * Create from existing private key bytes.
     */
    public X25519KeyGen(byte[] privateKeyBytes) {
        this.privateKey = privateKeyBytes.clone();
        X25519PrivateKeyParameters privParams = new X25519PrivateKeyParameters(privateKeyBytes, 0);
        this.publicKey = privParams.generatePublicKey().getEncoded();
    }

    private void generateKeyPair() {
        SecureRandom random = new SecureRandom();
        X25519KeyPairGenerator keyPairGenerator = new X25519KeyPairGenerator();
        keyPairGenerator.init(new X25519KeyGenerationParameters(random));

        AsymmetricCipherKeyPair keyPair = keyPairGenerator.generateKeyPair();

        X25519PrivateKeyParameters privParams = (X25519PrivateKeyParameters) keyPair.getPrivate();
        X25519PublicKeyParameters pubParams = (X25519PublicKeyParameters) keyPair.getPublic();

        this.privateKey = privParams.getEncoded();
        this.publicKey = pubParams.getEncoded();
    }

    /**
     * Get raw 32-byte private key.
     */
    public byte[] getPrivateKeyBytes() {
        return privateKey.clone();
    }

    /**
     * Get raw 32-byte public key.
     */
    public byte[] getPublicKeyBytes() {
        return publicKey.clone();
    }

    /**
     * Get age-format public key (age1...).
     */
    public String getAgePublicKey() {
        return Bech32.encode("age1", publicKey);
    }

    /**
     * Get age-format private key (AGE-SECRET-KEY-1...).
     */
    public String getAgePrivateKey() {
        String bech32 = Bech32.encode("age-secret-key-1", privateKey);
        return bech32.toUpperCase();
    }

    /**
     * Get the full age key file content.
     */
    public String getAgeKeyFile() {
        return "# created: " + java.time.Instant.now().toString() + "\n" +
               "# public key: " + getAgePublicKey() + "\n" +
               getAgePrivateKey() + "\n";
    }
}
