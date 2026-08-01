{
  # Host Configuration
  hostname = "barnfold";
  domain = "barn";

  # Locale & Time
  timeZone = "Europe/London";
  locale = "en_GB.UTF-8";
  keyMap = "uk";
  phoneRegion = "GB";

  # Network
  interface = "enp3s0";
  ipAddress = "192.168.0.67";
  prefixLength = 24;
  gateway = "192.168.0.1";
  nameservers = [ "127.0.0.1" "1.1.1.1" "9.9.9.9" ];

  # SSH
  sshPort = 67;
  sshKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPHEr9l0xPvco+x1zz2X5skaIwpjtI0+QGOELm/KtV5d kiroshi" ];

  # Admin User
  adminUser = "admin";

  # Services - Nextcloud
  nextcloudDomain = "cloud.barnfold";
  nextcloudDataDir = "/srv/data/nextcloud";
  nextcloudMaxUpload = "16G";
  nextcloudPort = 8080;

  # Services - AdGuard / DNS
  adguardPort = 3000;
  dnsPort = 53;
  dnsDomain = "dns.barnfold";
  upstreamDns = [ "https://dns.cloudflare.com/dns-query" "https://dns.quad9.net/dns-query" ];
  bootstrapDns = [ "1.1.1.1" "9.9.9.9" ];

  # Fail2ban
  fail2banMaxRetry = 5;
  fail2banBantime = "1h";

  # Disks
  osDisk = "/dev/nvme0n1";
  dataDisk = "/dev/sda1";
  dataMount = "/srv/data";
}
