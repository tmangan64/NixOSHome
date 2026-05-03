package nixgen.generator.templates;

public class SopsYamlTemplate {
    /**
     * Generate .sops.yaml configuration file.
     *
     * @param userAgePublicKey  The workstation age public key (age1...)
     * @param hostAgePublicKey  The server's SSH-derived age public key (age1...)
     * @param hostname          The hostname for the comment
     */
    public static String generate(String userAgePublicKey, String hostAgePublicKey, String hostname) {
        return String.format("""
keys:
  # Your workstation age key - generate with: age-keygen -o ~/.config/sops/age/keys.txt
  - &user_key %s
  # Server's SSH host key (%s) - derived via ssh-to-age
  - &host_%s %s

creation_rules:
  - path_regex: secrets/secrets\\.yaml$
    key_groups:
      - age:
          - *user_key
          - *host_%s
""", userAgePublicKey, hostname, hostname, hostAgePublicKey, hostname);
    }
}
