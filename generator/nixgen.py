#!/usr/bin/env python3
"""
NixOS Options Generator GUI

A tkinter application that generates options.nix and secrets.yaml files
for deploying a NixOS home server configuration.
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import re
import os
from pathlib import Path


class ToolTip:
    """Create a tooltip for a given widget."""

    def __init__(self, widget, text):
        self.widget = widget
        self.text = text
        self.tooltip = None
        widget.bind("<Enter>", self.show)
        widget.bind("<Leave>", self.hide)

    def show(self, event=None):
        x, y, _, _ = self.widget.bbox("insert") if self.widget.bbox("insert") else (0, 0, 0, 0)
        x += self.widget.winfo_rootx() + 25
        y += self.widget.winfo_rooty() + 25

        self.tooltip = tk.Toplevel(self.widget)
        self.tooltip.wm_overrideredirect(True)
        self.tooltip.wm_geometry(f"+{x}+{y}")

        label = tk.Label(
            self.tooltip,
            text=self.text,
            background="#ffffe0",
            relief="solid",
            borderwidth=1,
            font=("TkDefaultFont", 9),
            wraplength=300,
            justify="left",
        )
        label.pack()

    def hide(self, event=None):
        if self.tooltip:
            self.tooltip.destroy()
            self.tooltip = None


class NixGenApp:
    """Main application class."""

    def __init__(self, root):
        self.root = root
        self.root.title("NixOS Options Generator")
        self.root.geometry("800x700")

        # Determine paths - flake is at repository root
        self.script_dir = Path(__file__).parent.resolve()
        self.repo_dir = self.script_dir.parent
        self.options_dir = self.repo_dir / "options"

        # Create main notebook for tabs
        self.notebook = ttk.Notebook(root)
        self.notebook.pack(fill="both", expand=True, padx=10, pady=10)

        # Create frames for each tab
        self.host_frame = ttk.Frame(self.notebook, padding=10)
        self.network_frame = ttk.Frame(self.notebook, padding=10)
        self.ssh_frame = ttk.Frame(self.notebook, padding=10)
        self.services_frame = ttk.Frame(self.notebook, padding=10)
        self.disks_frame = ttk.Frame(self.notebook, padding=10)

        self.notebook.add(self.host_frame, text="Host & Locale")
        self.notebook.add(self.network_frame, text="Network")
        self.notebook.add(self.ssh_frame, text="SSH & User")
        self.notebook.add(self.services_frame, text="Services")
        self.notebook.add(self.disks_frame, text="Disks")

        # Initialize all fields
        self.fields = {}
        self.create_host_tab()
        self.create_network_tab()
        self.create_ssh_tab()
        self.create_services_tab()
        self.create_disks_tab()

        # Create button frame
        btn_frame = ttk.Frame(root, padding=10)
        btn_frame.pack(fill="x")

        ttk.Button(btn_frame, text="Generate", command=self.generate).pack(side="right", padx=5)
        ttk.Button(btn_frame, text="Reset to Defaults", command=self.reset_defaults).pack(side="right", padx=5)

        # Status bar
        self.status_var = tk.StringVar(value="Ready")
        status_bar = ttk.Label(root, textvariable=self.status_var, relief="sunken", anchor="w")
        status_bar.pack(fill="x", side="bottom")

    def create_labeled_entry(self, parent, label, default, tooltip, row, width=40):
        """Create a labeled entry field with tooltip."""
        ttk.Label(parent, text=label).grid(row=row, column=0, sticky="w", pady=2)
        var = tk.StringVar(value=default)
        entry = ttk.Entry(parent, textvariable=var, width=width)
        entry.grid(row=row, column=1, sticky="ew", pady=2, padx=5)
        ToolTip(entry, tooltip)
        return var

    def create_labeled_spinbox(self, parent, label, default, tooltip, row, min_val=0, max_val=65535):
        """Create a labeled spinbox field with tooltip."""
        ttk.Label(parent, text=label).grid(row=row, column=0, sticky="w", pady=2)
        var = tk.IntVar(value=default)
        spinbox = ttk.Spinbox(parent, textvariable=var, from_=min_val, to=max_val, width=10)
        spinbox.grid(row=row, column=1, sticky="w", pady=2, padx=5)
        ToolTip(spinbox, tooltip)
        return var

    def create_labeled_text(self, parent, label, default, tooltip, row, height=4):
        """Create a labeled text area with tooltip."""
        ttk.Label(parent, text=label).grid(row=row, column=0, sticky="nw", pady=2)
        text = scrolledtext.ScrolledText(parent, height=height, width=50)
        text.grid(row=row, column=1, sticky="ew", pady=2, padx=5)
        text.insert("1.0", default)
        ToolTip(text, tooltip)
        return text

    def create_host_tab(self):
        """Create the Host & Locale tab."""
        frame = self.host_frame
        frame.columnconfigure(1, weight=1)

        self.fields["hostname"] = self.create_labeled_entry(
            frame, "Hostname:", "homeserver",
            "The hostname for your server (e.g., homeserver, nixbox)", 0
        )
        self.fields["domain"] = self.create_labeled_entry(
            frame, "Domain:", "home",
            "The local domain suffix (e.g., home, local, lan)", 1
        )
        self.fields["timeZone"] = self.create_labeled_entry(
            frame, "Timezone:", "Europe/London",
            "Your timezone (e.g., Europe/London, America/New_York, Asia/Tokyo)", 2
        )
        self.fields["locale"] = self.create_labeled_entry(
            frame, "Locale:", "en_GB.UTF-8",
            "System locale (e.g., en_GB.UTF-8, en_US.UTF-8)", 3
        )
        self.fields["keyMap"] = self.create_labeled_entry(
            frame, "Keymap:", "uk",
            "Console keyboard layout (e.g., uk, us, de)", 4
        )
        self.fields["phoneRegion"] = self.create_labeled_entry(
            frame, "Phone Region:", "GB",
            "ISO 3166-1 country code for phone number formatting (e.g., GB, US, DE)", 5
        )

    def create_network_tab(self):
        """Create the Network tab."""
        frame = self.network_frame
        frame.columnconfigure(1, weight=1)

        self.fields["interface"] = self.create_labeled_entry(
            frame, "Network Interface:", "enp3s0",
            "Network interface name. Find with: ip link show", 0
        )
        self.fields["ipAddress"] = self.create_labeled_entry(
            frame, "IP Address:", "192.168.0.66",
            "Static IP address for the server", 1
        )
        self.fields["prefixLength"] = self.create_labeled_spinbox(
            frame, "Prefix Length:", 24,
            "Network prefix length (24 = 255.255.255.0)", 2, 1, 32
        )
        self.fields["gateway"] = self.create_labeled_entry(
            frame, "Gateway:", "192.168.0.1",
            "Default gateway/router IP address", 3
        )
        self.fields["nameservers"] = self.create_labeled_text(
            frame, "Nameservers:", "127.0.0.1\n1.1.1.1\n9.9.9.9",
            "DNS servers, one per line. 127.0.0.1 uses local AdGuard Home.", 4, 3
        )

    def create_ssh_tab(self):
        """Create the SSH & User tab."""
        frame = self.ssh_frame
        frame.columnconfigure(1, weight=1)

        self.fields["sshPort"] = self.create_labeled_spinbox(
            frame, "SSH Port:", 2266,
            "SSH port (non-standard port recommended for security)", 0, 1, 65535
        )
        self.fields["adminUser"] = self.create_labeled_entry(
            frame, "Admin Username:", "admin",
            "Administrator username for the server", 1
        )
        self.fields["sshKeys"] = self.create_labeled_text(
            frame, "SSH Public Keys:", "",
            "SSH public keys for authentication, one per line.\n"
            "Get yours with: cat ~/.ssh/id_ed25519.pub", 2, 5
        )

        # Password section with instructions
        ttk.Separator(frame, orient="horizontal").grid(row=3, column=0, columnspan=2, sticky="ew", pady=10)

        pwd_label = ttk.Label(
            frame,
            text="Password Setup",
            font=("TkDefaultFont", 10, "bold")
        )
        pwd_label.grid(row=4, column=0, columnspan=2, sticky="w", pady=5)

        instructions = ttk.Label(
            frame,
            text="Generate a password hash by running:\n  mkpasswd -m sha-512\n"
                 "Then paste the resulting hash below.",
            foreground="gray",
            justify="left"
        )
        instructions.grid(row=5, column=0, columnspan=2, sticky="w", pady=5)

        self.fields["passwordHash"] = self.create_labeled_text(
            frame, "Password Hash:", "",
            "Paste the hashed password from mkpasswd here", 6, 2
        )

        # Nextcloud password
        ttk.Separator(frame, orient="horizontal").grid(row=7, column=0, columnspan=2, sticky="ew", pady=10)

        nc_label = ttk.Label(
            frame,
            text="Nextcloud Admin Password",
            font=("TkDefaultFont", 10, "bold")
        )
        nc_label.grid(row=8, column=0, columnspan=2, sticky="w", pady=5)

        nc_instructions = ttk.Label(
            frame,
            text="Enter a plain-text password for the Nextcloud admin account.",
            foreground="gray",
            justify="left"
        )
        nc_instructions.grid(row=9, column=0, columnspan=2, sticky="w", pady=5)

        self.fields["nextcloudPassword"] = self.create_labeled_entry(
            frame, "Nextcloud Password:", "",
            "Plain-text password for Nextcloud admin login", 10
        )

    def create_services_tab(self):
        """Create the Services tab."""
        frame = self.services_frame
        frame.columnconfigure(1, weight=1)

        # Nextcloud section
        nc_label = ttk.Label(frame, text="Nextcloud", font=("TkDefaultFont", 10, "bold"))
        nc_label.grid(row=0, column=0, columnspan=2, sticky="w", pady=(0, 5))

        self.fields["nextcloudDomain"] = self.create_labeled_entry(
            frame, "Domain:", "cloud.home",
            "Domain name for Nextcloud (e.g., cloud.home)", 1
        )
        self.fields["nextcloudDataDir"] = self.create_labeled_entry(
            frame, "Data Directory:", "/srv/data/nextcloud",
            "Directory for Nextcloud data storage", 2
        )
        self.fields["nextcloudMaxUpload"] = self.create_labeled_entry(
            frame, "Max Upload Size:", "16G",
            "Maximum upload file size (e.g., 16G, 1G)", 3
        )
        self.fields["nextcloudPort"] = self.create_labeled_spinbox(
            frame, "Internal Port:", 8080,
            "Internal port for Nextcloud (proxied by Caddy)", 4, 1, 65535
        )

        # AdGuard section
        ttk.Separator(frame, orient="horizontal").grid(row=5, column=0, columnspan=2, sticky="ew", pady=10)
        ag_label = ttk.Label(frame, text="AdGuard Home / DNS", font=("TkDefaultFont", 10, "bold"))
        ag_label.grid(row=6, column=0, columnspan=2, sticky="w", pady=5)

        self.fields["adguardPort"] = self.create_labeled_spinbox(
            frame, "Admin Port:", 3000,
            "AdGuard Home web interface port", 7, 1, 65535
        )
        self.fields["dnsPort"] = self.create_labeled_spinbox(
            frame, "DNS Port:", 53,
            "DNS server port (usually 53)", 8, 1, 65535
        )
        self.fields["dnsDomain"] = self.create_labeled_entry(
            frame, "DNS Domain:", "dns.home",
            "Domain for AdGuard Home web interface", 9
        )
        self.fields["upstreamDns"] = self.create_labeled_text(
            frame, "Upstream DNS:", "https://dns.cloudflare.com/dns-query\nhttps://dns.quad9.net/dns-query",
            "Upstream DNS servers (DNS-over-HTTPS recommended), one per line", 10, 2
        )
        self.fields["bootstrapDns"] = self.create_labeled_text(
            frame, "Bootstrap DNS:", "1.1.1.1\n9.9.9.9",
            "Bootstrap DNS servers for resolving DoH hostnames, one per line", 11, 2
        )

        # Fail2ban section
        ttk.Separator(frame, orient="horizontal").grid(row=12, column=0, columnspan=2, sticky="ew", pady=10)
        f2b_label = ttk.Label(frame, text="Fail2ban", font=("TkDefaultFont", 10, "bold"))
        f2b_label.grid(row=13, column=0, columnspan=2, sticky="w", pady=5)

        self.fields["fail2banMaxRetry"] = self.create_labeled_spinbox(
            frame, "Max Retries:", 5,
            "Number of failed attempts before banning", 14, 1, 100
        )
        self.fields["fail2banBantime"] = self.create_labeled_entry(
            frame, "Ban Time:", "1h",
            "Initial ban duration (e.g., 1h, 30m, 1d)", 15
        )

    def create_disks_tab(self):
        """Create the Disks tab."""
        frame = self.disks_frame
        frame.columnconfigure(1, weight=1)

        ttk.Label(
            frame,
            text="Disk Configuration",
            font=("TkDefaultFont", 10, "bold")
        ).grid(row=0, column=0, columnspan=2, sticky="w", pady=(0, 5))

        instructions = ttk.Label(
            frame,
            text="Find disk devices with: lsblk -d -o NAME,SIZE,MODEL",
            foreground="gray"
        )
        instructions.grid(row=1, column=0, columnspan=2, sticky="w", pady=5)

        self.fields["osDisk"] = self.create_labeled_entry(
            frame, "OS Disk:", "/dev/nvme0n1",
            "Disk for the operating system (will be formatted!)", 2
        )
        self.fields["dataDisk"] = self.create_labeled_entry(
            frame, "Data Disk/Partition:", "/dev/sda1",
            "Partition for data storage (Nextcloud, etc.)", 3
        )
        self.fields["dataMount"] = self.create_labeled_entry(
            frame, "Data Mount Point:", "/srv/data",
            "Mount point for the data partition", 4
        )

        # Warning
        ttk.Separator(frame, orient="horizontal").grid(row=5, column=0, columnspan=2, sticky="ew", pady=10)
        warning = ttk.Label(
            frame,
            text="WARNING: The OS disk will be completely formatted during installation!\n"
                 "Make sure you have the correct device path.",
            foreground="red",
            justify="left"
        )
        warning.grid(row=6, column=0, columnspan=2, sticky="w", pady=5)

    def get_text_value(self, text_widget):
        """Get value from a Text widget, stripping whitespace."""
        return text_widget.get("1.0", "end-1c").strip()

    def get_text_list(self, text_widget):
        """Get a list of non-empty lines from a Text widget."""
        content = self.get_text_value(text_widget)
        return [line.strip() for line in content.split("\n") if line.strip()]

    def validate_ip(self, ip):
        """Validate an IP address."""
        pattern = r"^(\d{1,3}\.){3}\d{1,3}$"
        if not re.match(pattern, ip):
            return False
        parts = ip.split(".")
        return all(0 <= int(p) <= 255 for p in parts)

    def validate(self):
        """Validate all input fields."""
        errors = []

        # Validate IP addresses
        ip_address = self.fields["ipAddress"].get()
        if not self.validate_ip(ip_address):
            errors.append(f"Invalid IP address: {ip_address}")

        gateway = self.fields["gateway"].get()
        if not self.validate_ip(gateway):
            errors.append(f"Invalid gateway: {gateway}")

        # Validate nameservers
        nameservers = self.get_text_list(self.fields["nameservers"])
        for ns in nameservers:
            if not self.validate_ip(ns):
                errors.append(f"Invalid nameserver: {ns}")

        # Validate SSH keys exist
        ssh_keys = self.get_text_list(self.fields["sshKeys"])
        if not ssh_keys:
            errors.append("At least one SSH public key is required")

        # Validate password hash
        password_hash = self.get_text_value(self.fields["passwordHash"])
        if not password_hash:
            errors.append("Password hash is required. Run: mkpasswd -m sha-512")

        # Validate Nextcloud password
        nc_password = self.fields["nextcloudPassword"].get()
        if not nc_password:
            errors.append("Nextcloud admin password is required")

        # Validate hostname (alphanumeric and hyphens only)
        hostname = self.fields["hostname"].get()
        if not re.match(r"^[a-zA-Z][a-zA-Z0-9-]*$", hostname):
            errors.append("Hostname must start with a letter and contain only letters, numbers, and hyphens")

        # Validate ports are in range
        for port_field in ["sshPort", "nextcloudPort", "adguardPort", "dnsPort"]:
            port = self.fields[port_field].get()
            if not (1 <= port <= 65535):
                errors.append(f"Port {port_field} must be between 1 and 65535")

        return errors

    def generate_options_nix(self):
        """Generate the options.nix content."""
        def nix_string(val):
            return f'"{val}"'

        def nix_list(items):
            if not items:
                return "[ ]"
            formatted = " ".join(nix_string(item) for item in items)
            return f"[ {formatted} ]"

        nameservers = self.get_text_list(self.fields["nameservers"])
        ssh_keys = self.get_text_list(self.fields["sshKeys"])
        upstream_dns = self.get_text_list(self.fields["upstreamDns"])
        bootstrap_dns = self.get_text_list(self.fields["bootstrapDns"])

        content = f"""\
{{
  # Host Configuration
  hostname = {nix_string(self.fields["hostname"].get())};
  domain = {nix_string(self.fields["domain"].get())};

  # Locale & Time
  timeZone = {nix_string(self.fields["timeZone"].get())};
  locale = {nix_string(self.fields["locale"].get())};
  keyMap = {nix_string(self.fields["keyMap"].get())};
  phoneRegion = {nix_string(self.fields["phoneRegion"].get())};

  # Network
  interface = {nix_string(self.fields["interface"].get())};
  ipAddress = {nix_string(self.fields["ipAddress"].get())};
  prefixLength = {self.fields["prefixLength"].get()};
  gateway = {nix_string(self.fields["gateway"].get())};
  nameservers = {nix_list(nameservers)};

  # SSH
  sshPort = {self.fields["sshPort"].get()};
  sshKeys = {nix_list(ssh_keys)};

  # Admin User
  adminUser = {nix_string(self.fields["adminUser"].get())};

  # Services - Nextcloud
  nextcloudDomain = {nix_string(self.fields["nextcloudDomain"].get())};
  nextcloudDataDir = {nix_string(self.fields["nextcloudDataDir"].get())};
  nextcloudMaxUpload = {nix_string(self.fields["nextcloudMaxUpload"].get())};
  nextcloudPort = {self.fields["nextcloudPort"].get()};

  # Services - AdGuard / DNS
  adguardPort = {self.fields["adguardPort"].get()};
  dnsPort = {self.fields["dnsPort"].get()};
  dnsDomain = {nix_string(self.fields["dnsDomain"].get())};
  upstreamDns = {nix_list(upstream_dns)};
  bootstrapDns = {nix_list(bootstrap_dns)};

  # Fail2ban
  fail2banMaxRetry = {self.fields["fail2banMaxRetry"].get()};
  fail2banBantime = {nix_string(self.fields["fail2banBantime"].get())};

  # Disks
  osDisk = {nix_string(self.fields["osDisk"].get())};
  dataDisk = {nix_string(self.fields["dataDisk"].get())};
  dataMount = {nix_string(self.fields["dataMount"].get())};
}}
"""
        return content

    def generate_secrets_yaml(self):
        """Generate the secrets.yaml content (unencrypted)."""
        admin_user = self.fields["adminUser"].get()
        password_hash = self.get_text_value(self.fields["passwordHash"])
        nc_password = self.fields["nextcloudPassword"].get()

        content = f"""\
{admin_user}:
    password_hash: "{password_hash}"
nextcloud:
    admin_password: "{nc_password}"
"""
        return content

    def generate(self):
        """Generate the configuration files."""
        # Validate input
        errors = self.validate()
        if errors:
            messagebox.showerror("Validation Error", "\n".join(errors))
            return

        try:
            # Ensure output directory exists
            self.options_dir.mkdir(parents=True, exist_ok=True)

            # Generate options.nix
            options_content = self.generate_options_nix()
            options_path = self.options_dir / "options.nix"
            options_path.write_text(options_content)

            # Generate secrets.yaml
            secrets_content = self.generate_secrets_yaml()
            secrets_path = self.options_dir / "secrets.yaml"
            secrets_path.write_text(secrets_content)

            # Show success message with next steps
            success_msg = f"""\
Files generated successfully!

Created:
  - {options_path}
  - {secrets_path}

IMPORTANT: Next Steps

1. The secrets.yaml file contains unencrypted secrets.
   You MUST encrypt it with SOPS before committing.

2. Configure SOPS:
   - Copy .sops.yaml.template to options/.sops.yaml
   - Add your age public key (from: age-keygen)

3. Encrypt secrets:
   cd {self.options_dir}
   sops --encrypt --in-place secrets.yaml

4. Deploy with nixos-anywhere:
   nix run github:nix-community/nixos-anywhere -- \\
     --flake .#hostname root@target-ip

See README.md for detailed instructions.
"""
            messagebox.showinfo("Success", success_msg)
            self.status_var.set(f"Generated: {options_path}")

        except Exception as e:
            messagebox.showerror("Error", f"Failed to generate files:\n{e}")
            self.status_var.set("Error generating files")

    def reset_defaults(self):
        """Reset all fields to their default values."""
        defaults = {
            "hostname": "homeserver",
            "domain": "home",
            "timeZone": "Europe/London",
            "locale": "en_GB.UTF-8",
            "keyMap": "uk",
            "phoneRegion": "GB",
            "interface": "enp3s0",
            "ipAddress": "192.168.0.66",
            "prefixLength": 24,
            "gateway": "192.168.0.1",
            "sshPort": 2266,
            "adminUser": "admin",
            "nextcloudDomain": "cloud.home",
            "nextcloudDataDir": "/srv/data/nextcloud",
            "nextcloudMaxUpload": "16G",
            "nextcloudPort": 8080,
            "adguardPort": 3000,
            "dnsPort": 53,
            "dnsDomain": "dns.home",
            "fail2banMaxRetry": 5,
            "fail2banBantime": "1h",
            "osDisk": "/dev/nvme0n1",
            "dataDisk": "/dev/sda1",
            "dataMount": "/srv/data",
            "nextcloudPassword": "",
        }

        text_defaults = {
            "nameservers": "127.0.0.1\n1.1.1.1\n9.9.9.9",
            "sshKeys": "",
            "passwordHash": "",
            "upstreamDns": "https://dns.cloudflare.com/dns-query\nhttps://dns.quad9.net/dns-query",
            "bootstrapDns": "1.1.1.1\n9.9.9.9",
        }

        for key, value in defaults.items():
            if key in self.fields:
                if isinstance(self.fields[key], (tk.StringVar, tk.IntVar)):
                    self.fields[key].set(value)

        for key, value in text_defaults.items():
            if key in self.fields:
                widget = self.fields[key]
                if isinstance(widget, (tk.Text, scrolledtext.ScrolledText)):
                    widget.delete("1.0", "end")
                    widget.insert("1.0", value)

        self.status_var.set("Reset to defaults")


def main():
    root = tk.Tk()
    app = NixGenApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
