package nixgen.gui;

import nixgen.model.ConfigData;

import javax.swing.*;
import java.awt.*;

/**
 * Network configuration form panel.
 */
public class NetworkPanel extends JPanel {
    private final ConfigData config;

    private final JTextField hostnameField;
    private final JTextField domainField;
    private final JTextField interfaceField;
    private final JTextField ipField;
    private final JSpinner prefixSpinner;
    private final JTextField gatewayField;
    private final JSpinner sshPortSpinner;

    public NetworkPanel(ConfigData config) {
        this.config = config;

        setLayout(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(5, 10, 5, 10);
        gbc.fill = GridBagConstraints.HORIZONTAL;
        gbc.anchor = GridBagConstraints.WEST;

        int row = 0;

        // Hostname
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Hostname:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        hostnameField = new JTextField(config.getHostname(), 20);
        add(hostnameField, gbc);
        row++;

        // Domain
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Domain:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        domainField = new JTextField(config.getDomain(), 20);
        add(domainField, gbc);
        gbc.gridx = 2;
        gbc.weightx = 0;
        add(new JLabel("(creates dns.{domain}, nas.{domain})"), gbc);
        row++;

        // Network Interface
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Network Interface:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        interfaceField = new JTextField(config.getNetworkInterface(), 20);
        add(interfaceField, gbc);
        gbc.gridx = 2;
        gbc.weightx = 0;
        add(new JLabel("(e.g., enp3s0, eth0)"), gbc);
        row++;

        // Static IP
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Static IP:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        ipField = new JTextField(config.getStaticIp(), 20);
        add(ipField, gbc);
        row++;

        // Prefix Length
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Prefix Length:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        prefixSpinner = new JSpinner(new SpinnerNumberModel(config.getPrefixLength(), 1, 32, 1));
        add(prefixSpinner, gbc);
        gbc.gridx = 2;
        gbc.weightx = 0;
        add(new JLabel("(24 = 255.255.255.0)"), gbc);
        row++;

        // Gateway
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Gateway:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        gatewayField = new JTextField(config.getGateway(), 20);
        add(gatewayField, gbc);
        row++;

        // SSH Port
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("SSH Port:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        sshPortSpinner = new JSpinner(new SpinnerNumberModel(config.getSshPort(), 1, 65535, 1));
        add(sshPortSpinner, gbc);
        gbc.gridx = 2;
        gbc.weightx = 0;
        add(new JLabel("(non-standard recommended)"), gbc);
        row++;

        // Filler
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weighty = 1;
        gbc.gridwidth = 3;
        add(new JPanel(), gbc);
    }

    public void updateConfig() {
        config.setHostname(hostnameField.getText().trim());
        config.setDomain(domainField.getText().trim());
        config.setNetworkInterface(interfaceField.getText().trim());
        config.setStaticIp(ipField.getText().trim());
        config.setPrefixLength((Integer) prefixSpinner.getValue());
        config.setGateway(gatewayField.getText().trim());
        config.setSshPort((Integer) sshPortSpinner.getValue());
    }
}
