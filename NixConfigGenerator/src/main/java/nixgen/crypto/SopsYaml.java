package nixgen.crypto;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Generates SOPS-compatible YAML with encrypted values.
 */
public class SopsYaml {
    private final List<String> recipientPublicKeys;
    private final Map<String, String> secrets;
    private byte[] dataKey;

    public SopsYaml(List<String> recipientPublicKeys) {
        this.recipientPublicKeys = recipientPublicKeys;
        this.secrets = new LinkedHashMap<>();
    }

    /**
     * Add a secret to be encrypted.
     */
    public void addSecret(String path, String plaintext) {
        secrets.put(path, plaintext);
    }

    /**
     * Generate the SOPS-encrypted YAML.
     */
    public String generate() {
        SecureRandom random = new SecureRandom();

        // Generate data key
        dataKey = new byte[32];
        random.nextBytes(dataKey);

        StringBuilder yaml = new StringBuilder();

        // Encrypt each secret and add to YAML
        Map<String, Map<String, String>> structure = new LinkedHashMap<>();

        for (Map.Entry<String, String> entry : secrets.entrySet()) {
            String path = entry.getKey();
            String plaintext = entry.getValue();

            // Parse path like "admin/password_hash" into nested structure
            String[] parts = path.split("/");
            String encryptedValue = encryptValue(plaintext, dataKey, random);

            if (parts.length == 2) {
                structure.computeIfAbsent(parts[0], k -> new LinkedHashMap<>())
                         .put(parts[1], encryptedValue);
            }
        }

        // Write secrets section
        for (Map.Entry<String, Map<String, String>> topLevel : structure.entrySet()) {
            yaml.append(topLevel.getKey()).append(":\n");
            for (Map.Entry<String, String> nested : topLevel.getValue().entrySet()) {
                yaml.append("    ").append(nested.getKey()).append(": ").append(nested.getValue()).append("\n");
            }
        }

        // Write SOPS metadata
        yaml.append("sops:\n");
        yaml.append("    age:\n");

        // Encrypt data key for each recipient
        AgeEncrypt.EncryptedValue keyWrap = AgeEncrypt.encrypt(dataKey, recipientPublicKeys);

        for (AgeEncrypt.RecipientStanza stanza : keyWrap.stanzas) {
            yaml.append("        - recipient: ").append(stanza.recipientPublicKey).append("\n");
            yaml.append("          enc: |\n");

            String ageBlock = formatAgeBlock(stanza, random);
            for (String line : ageBlock.split("\n")) {
                yaml.append("            ").append(line).append("\n");
            }
        }

        // Add timestamp
        String timestamp = DateTimeFormatter.ISO_INSTANT.format(Instant.now().atZone(ZoneOffset.UTC));
        yaml.append("    lastmodified: \"").append(timestamp).append("\"\n");

        // Add MAC
        String mac = generateMac(structure, dataKey, random);
        yaml.append("    mac: ").append(mac).append("\n");

        yaml.append("    unencrypted_suffix: _unencrypted\n");
        yaml.append("    version: 3.9.0\n");

        return yaml.toString();
    }

    /**
     * Encrypt a single value using AES-256-GCM format for SOPS.
     */
    private String encryptValue(String plaintext, byte[] key, SecureRandom random) {
        try {
            byte[] iv = new byte[12];
            random.nextBytes(iv);

            // Use first 32 bytes of key for AES-256
            byte[] aesKey = Arrays.copyOf(key, 32);

            // AES-GCM encrypt
            javax.crypto.Cipher cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding");
            javax.crypto.spec.GCMParameterSpec spec = new javax.crypto.spec.GCMParameterSpec(128, iv);
            cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, new javax.crypto.spec.SecretKeySpec(aesKey, "AES"), spec);

            byte[] ciphertext = cipher.doFinal(plaintext.getBytes("UTF-8"));

            // Split ciphertext and tag (tag is last 16 bytes)
            byte[] data = Arrays.copyOf(ciphertext, ciphertext.length - 16);
            byte[] tag = Arrays.copyOfRange(ciphertext, ciphertext.length - 16, ciphertext.length);

            String b64Data = Base64.getEncoder().encodeToString(data);
            String b64Iv = Base64.getEncoder().encodeToString(iv);
            String b64Tag = Base64.getEncoder().encodeToString(tag);

            return String.format("ENC[AES256_GCM,data:%s,iv:%s,tag:%s,type:str]", b64Data, b64Iv, b64Tag);
        } catch (Exception e) {
            throw new RuntimeException("Failed to encrypt value", e);
        }
    }

    /**
     * Format an age recipient block.
     */
    private String formatAgeBlock(AgeEncrypt.RecipientStanza stanza, SecureRandom random) {
        StringBuilder sb = new StringBuilder();
        sb.append("-----BEGIN AGE ENCRYPTED FILE-----\n");

        // Create the age header
        byte[] ephemeralPubBytes = Bech32.decode("age1", stanza.ephemeralPublicKey);
        String ephemeralB64 = Base64.getEncoder().withoutPadding().encodeToString(ephemeralPubBytes);

        // age stanza: "age-encryption.org/v1\n-> X25519 <ephemeral>\n<wrapped-key>\n---"
        String header = "age-encryption.org/v1\n-> X25519 " + ephemeralB64 + "\n";
        String wrappedKey = Base64.getEncoder().withoutPadding().encodeToString(stanza.encryptedFileKey);
        String fullContent = header + wrappedKey + "\n---";

        // Base64 encode the whole thing with line wrapping
        String b64 = Base64.getEncoder().encodeToString(fullContent.getBytes());
        for (int i = 0; i < b64.length(); i += 64) {
            sb.append(b64, i, Math.min(i + 64, b64.length())).append("\n");
        }

        sb.append("-----END AGE ENCRYPTED FILE-----");
        return sb.toString();
    }

    /**
     * Generate HMAC for SOPS integrity.
     */
    private String generateMac(Map<String, Map<String, String>> structure, byte[] key, SecureRandom random) {
        try {
            // Compute HMAC-SHA256 over all encrypted values
            javax.crypto.Mac mac = javax.crypto.Mac.getInstance("HmacSHA256");
            mac.init(new javax.crypto.spec.SecretKeySpec(key, "HmacSHA256"));

            for (Map<String, String> nested : structure.values()) {
                for (String value : nested.values()) {
                    mac.update(value.getBytes("UTF-8"));
                }
            }

            byte[] macBytes = mac.doFinal();

            // Encrypt the MAC itself
            byte[] iv = new byte[12];
            random.nextBytes(iv);
            byte[] aesKey = Arrays.copyOf(key, 32);

            javax.crypto.Cipher cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding");
            javax.crypto.spec.GCMParameterSpec spec = new javax.crypto.spec.GCMParameterSpec(128, iv);
            cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, new javax.crypto.spec.SecretKeySpec(aesKey, "AES"), spec);

            byte[] encMac = cipher.doFinal(macBytes);
            byte[] data = Arrays.copyOf(encMac, encMac.length - 16);
            byte[] tag = Arrays.copyOfRange(encMac, encMac.length - 16, encMac.length);

            String b64Data = Base64.getEncoder().encodeToString(data);
            String b64Iv = Base64.getEncoder().encodeToString(iv);
            String b64Tag = Base64.getEncoder().encodeToString(tag);

            return String.format("ENC[AES256_GCM,data:%s,iv:%s,tag:%s,type:str]", b64Data, b64Iv, b64Tag);
        } catch (Exception e) {
            throw new RuntimeException("Failed to generate MAC", e);
        }
    }
}
