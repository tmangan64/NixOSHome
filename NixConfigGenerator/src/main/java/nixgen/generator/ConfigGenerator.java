package nixgen.generator;

import nixgen.crypto.*;
import nixgen.generator.templates.*;
import nixgen.model.ConfigData;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.List;

/**
 * Orchestrates the generation of all NixOS configuration files.
 */
public class ConfigGenerator {
    private final ConfigData config;
    private final File outputDir;

    // Generated keys
    private Ed25519KeyGen sshHostKey;
    private X25519KeyGen workstationAgeKey;
    private String hostAgePublicKey;

    public ConfigGenerator(ConfigData config, File outputDir) {
        this.config = config;
        this.outputDir = outputDir;
    }

    /**
     * Validate configuration before generation.
     */
    public String validate() {
        StringBuilder errors = new StringBuilder();

        if (config.getHostname() == null || config.getHostname().trim().isEmpty()) {
            errors.append("Hostname is required\n");
        }
        if (config.getDomain() == null || config.getDomain().trim().isEmpty()) {
            errors.append("Domain is required\n");
        }
        if (config.getNetworkInterface() == null || config.getNetworkInterface().trim().isEmpty()) {
            errors.append("Network interface is required\n");
        }
        if (config.getStaticIp() == null || config.getStaticIp().trim().isEmpty()) {
            errors.append("Static IP is required\n");
        }
        if (config.getGateway() == null || config.getGateway().trim().isEmpty()) {
            errors.append("Gateway is required\n");
        }
        if (config.getAdminUsername() == null || config.getAdminUsername().trim().isEmpty()) {
            errors.append("Admin username is required\n");
        }
        if (config.getAdminPassword() == null || config.getAdminPassword().trim().isEmpty()) {
            errors.append("Admin password is required\n");
        }
        if (config.getAdminSshPublicKey() == null || config.getAdminSshPublicKey().trim().isEmpty()) {
            errors.append("Admin SSH public key is required\n");
        }
        if (config.getNextcloudAdminPassword() == null || config.getNextcloudAdminPassword().trim().isEmpty()) {
            errors.append("Nextcloud admin password is required\n");
        }

        return errors.length() == 0 ? null : errors.toString();
    }

    /**
     * Generate all configuration files.
     */
    public void generate() throws IOException {
        // Create directory structure
        createDirectories();

        // Generate cryptographic keys
        generateKeys();

        // Generate NixOS configuration files
        generateNixFiles();

        // Generate SOPS configuration
        generateSopsConfig();

        // Generate secrets
        generateSecrets();

        // Save keys
        saveKeys();
    }

    private void createDirectories() throws IOException {
        Files.createDirectories(Path.of(outputDir.getPath(), "hosts", config.getHostname()));
        Files.createDirectories(Path.of(outputDir.getPath(), "modules"));
        Files.createDirectories(Path.of(outputDir.getPath(), "secrets"));
        Files.createDirectories(Path.of(outputDir.getPath(), "keys"));
    }

    private void generateKeys() {
        // Generate SSH host key
        sshHostKey = new Ed25519KeyGen();

        // Generate workstation age key
        workstationAgeKey = new X25519KeyGen();

        // Convert SSH host key to age public key
        hostAgePublicKey = SshToAge.getAgePublicKeyFromEd25519Public(sshHostKey.getPublicKeyBytes());
    }

    private void generateNixFiles() throws IOException {
        // flake.nix
        writeFile("flake.nix", FlakeTemplate.generate(config));

        // hosts/{hostname}/configuration.nix
        writeFile("hosts/" + config.getHostname() + "/configuration.nix",
                  ConfigurationTemplate.generate(config));

        // hosts/{hostname}/hardware.nix
        writeFile("hosts/" + config.getHostname() + "/hardware.nix",
                  HardwareTemplate.generate(config));

        // hosts/{hostname}/disko.nix
        writeFile("hosts/" + config.getHostname() + "/disko.nix",
                  DiskoTemplate.generate(config));

        // modules/users.nix
        writeFile("modules/users.nix", UsersTemplate.generate(config));

        // modules/networking.nix
        writeFile("modules/networking.nix", NetworkingTemplate.generate(config));

        // modules/secrets.nix
        writeFile("modules/secrets.nix", SecretsTemplate.generate(config));

        // modules/adguard.nix
        writeFile("modules/adguard.nix", AdguardTemplate.generate(config));

        // modules/caddy.nix
        writeFile("modules/caddy.nix", CaddyTemplate.generate(config));

        // modules/nextcloud.nix
        writeFile("modules/nextcloud.nix", NextcloudTemplate.generate(config));

        // modules/auto-upgrade.nix
        writeFile("modules/auto-upgrade.nix", AutoUpgradeTemplate.generate(config));
    }

    private void generateSopsConfig() throws IOException {
        String sopsYaml = SopsYamlTemplate.generate(
            workstationAgeKey.getAgePublicKey(),
            hostAgePublicKey,
            config.getHostname()
        );
        writeFile(".sops.yaml", sopsYaml);
    }

    private void generateSecrets() throws IOException {
        // Hash the admin password
        String passwordHash = Sha512Crypt.hash(config.getAdminPassword());

        // Create SOPS-encrypted secrets
        List<String> recipients = Arrays.asList(
            workstationAgeKey.getAgePublicKey(),
            hostAgePublicKey
        );

        SopsYaml sops = new SopsYaml(recipients);
        sops.addSecret("admin/password_hash", passwordHash);
        sops.addSecret("nextcloud/admin_password", config.getNextcloudAdminPassword());

        String secretsYaml = sops.generate();
        writeFile("secrets/secrets.yaml", secretsYaml);
    }

    private void saveKeys() throws IOException {
        // SSH host key pair
        writeFile("keys/ssh_host_ed25519_key", sshHostKey.getPrivateKeyOpenSSH());
        writeFile("keys/ssh_host_ed25519_key.pub", sshHostKey.getPublicKeyOpenSSH(config.getHostname()));

        // Workstation age key
        writeFile("keys/age_key.txt", workstationAgeKey.getAgeKeyFile());

        // Host age public key (for reference)
        writeFile("keys/host_age_public.txt",
                  "# Host age public key (derived from SSH host key)\n" +
                  "# This is automatically used by SOPS via the SSH key\n" +
                  hostAgePublicKey + "\n");
    }

    private void writeFile(String relativePath, String content) throws IOException {
        File file = new File(outputDir, relativePath);
        try (FileWriter writer = new FileWriter(file)) {
            writer.write(content);
        }
    }

    /**
     * Get the generated workstation age public key.
     */
    public String getWorkstationAgePublicKey() {
        return workstationAgeKey != null ? workstationAgeKey.getAgePublicKey() : null;
    }

    /**
     * Get the generated host age public key.
     */
    public String getHostAgePublicKey() {
        return hostAgePublicKey;
    }
}
