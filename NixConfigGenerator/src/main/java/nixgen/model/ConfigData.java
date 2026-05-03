package nixgen.model;

/**
 * POJO holding all user input for NixOS configuration generation.
 */
public class ConfigData {
    // Network settings
    private String hostname = "homeserver";
    private String domain = "home";
    private String networkInterface = "enp3s0";
    private String staticIp = "192.168.0.66";
    private int prefixLength = 24;
    private String gateway = "192.168.0.1";
    private int sshPort = 2266;

    // User settings
    private String adminUsername = "admin";
    private String adminPassword = "";
    private String adminSshPublicKey = "";

    // Service settings
    private String nextcloudAdminPassword = "";

    // System settings
    private String timezone = "Europe/London";
    private String locale = "en_GB.UTF-8";
    private String consoleKeymap = "uk";
    private String phoneRegion = "GB";
    private String githubFlakeUrl = "";

    // Getters and setters
    public String getHostname() { return hostname; }
    public void setHostname(String hostname) { this.hostname = hostname; }

    public String getDomain() { return domain; }
    public void setDomain(String domain) { this.domain = domain; }

    public String getNetworkInterface() { return networkInterface; }
    public void setNetworkInterface(String networkInterface) { this.networkInterface = networkInterface; }

    public String getStaticIp() { return staticIp; }
    public void setStaticIp(String staticIp) { this.staticIp = staticIp; }

    public int getPrefixLength() { return prefixLength; }
    public void setPrefixLength(int prefixLength) { this.prefixLength = prefixLength; }

    public String getGateway() { return gateway; }
    public void setGateway(String gateway) { this.gateway = gateway; }

    public int getSshPort() { return sshPort; }
    public void setSshPort(int sshPort) { this.sshPort = sshPort; }

    public String getAdminUsername() { return adminUsername; }
    public void setAdminUsername(String adminUsername) { this.adminUsername = adminUsername; }

    public String getAdminPassword() { return adminPassword; }
    public void setAdminPassword(String adminPassword) { this.adminPassword = adminPassword; }

    public String getAdminSshPublicKey() { return adminSshPublicKey; }
    public void setAdminSshPublicKey(String adminSshPublicKey) { this.adminSshPublicKey = adminSshPublicKey; }

    public String getNextcloudAdminPassword() { return nextcloudAdminPassword; }
    public void setNextcloudAdminPassword(String nextcloudAdminPassword) { this.nextcloudAdminPassword = nextcloudAdminPassword; }

    public String getTimezone() { return timezone; }
    public void setTimezone(String timezone) { this.timezone = timezone; }

    public String getLocale() { return locale; }
    public void setLocale(String locale) { this.locale = locale; }

    public String getConsoleKeymap() { return consoleKeymap; }
    public void setConsoleKeymap(String consoleKeymap) { this.consoleKeymap = consoleKeymap; }

    public String getPhoneRegion() { return phoneRegion; }
    public void setPhoneRegion(String phoneRegion) { this.phoneRegion = phoneRegion; }

    public String getGithubFlakeUrl() { return githubFlakeUrl; }
    public void setGithubFlakeUrl(String githubFlakeUrl) { this.githubFlakeUrl = githubFlakeUrl; }

    // Derived values
    public String getDnsDomain() { return "dns." + domain; }
    public String getNasDomain() { return "nas." + domain; }
}
