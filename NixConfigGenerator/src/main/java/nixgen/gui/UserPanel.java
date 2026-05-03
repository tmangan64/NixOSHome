package nixgen.gui;

import nixgen.model.ConfigData;

import javax.swing.*;
import java.awt.*;

/**
 * User and credentials configuration panel.
 */
public class UserPanel extends JPanel {
    private final ConfigData config;

    private final JTextField usernameField;
    private final JPasswordField passwordField;
    private final JPasswordField confirmPasswordField;
    private final JTextArea sshKeyArea;
    private final JPasswordField nextcloudPasswordField;
    private final JPasswordField nextcloudConfirmField;

    public UserPanel(ConfigData config) {
        this.config = config;

        setLayout(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(5, 10, 5, 10);
        gbc.fill = GridBagConstraints.HORIZONTAL;
        gbc.anchor = GridBagConstraints.NORTHWEST;

        int row = 0;

        // Section: Admin User
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 2;
        gbc.weightx = 1;
        JLabel adminLabel = new JLabel("Admin User Settings");
        adminLabel.setFont(adminLabel.getFont().deriveFont(Font.BOLD, 14f));
        add(adminLabel, gbc);
        row++;

        // Username
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 1;
        gbc.weightx = 0;
        add(new JLabel("Username:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        usernameField = new JTextField(config.getAdminUsername(), 20);
        add(usernameField, gbc);
        row++;

        // Password
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Password:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        passwordField = new JPasswordField(20);
        add(passwordField, gbc);
        row++;

        // Confirm Password
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Confirm Password:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        confirmPasswordField = new JPasswordField(20);
        add(confirmPasswordField, gbc);
        row++;

        // SSH Public Key
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        gbc.anchor = GridBagConstraints.NORTHWEST;
        add(new JLabel("SSH Public Key:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        gbc.fill = GridBagConstraints.BOTH;
        sshKeyArea = new JTextArea(3, 40);
        sshKeyArea.setLineWrap(true);
        sshKeyArea.setWrapStyleWord(false);
        JScrollPane sshScroll = new JScrollPane(sshKeyArea);
        add(sshScroll, gbc);
        row++;

        // Spacer
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 2;
        gbc.fill = GridBagConstraints.HORIZONTAL;
        add(Box.createVerticalStrut(20), gbc);
        row++;

        // Section: Nextcloud
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 2;
        JLabel nextcloudLabel = new JLabel("Nextcloud Settings");
        nextcloudLabel.setFont(nextcloudLabel.getFont().deriveFont(Font.BOLD, 14f));
        add(nextcloudLabel, gbc);
        row++;

        // Nextcloud Password
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 1;
        gbc.weightx = 0;
        add(new JLabel("Admin Password:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        nextcloudPasswordField = new JPasswordField(20);
        add(nextcloudPasswordField, gbc);
        row++;

        // Confirm Nextcloud Password
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Confirm Password:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        nextcloudConfirmField = new JPasswordField(20);
        add(nextcloudConfirmField, gbc);
        row++;

        // Note
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 2;
        JLabel note = new JLabel("<html><i>Note: Passwords will be hashed/encrypted before storage.</i></html>");
        note.setForeground(Color.GRAY);
        add(note, gbc);
        row++;

        // Filler
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weighty = 1;
        gbc.gridwidth = 2;
        add(new JPanel(), gbc);
    }

    public void updateConfig() {
        config.setAdminUsername(usernameField.getText().trim());

        String password = new String(passwordField.getPassword());
        String confirmPassword = new String(confirmPasswordField.getPassword());
        if (!password.equals(confirmPassword)) {
            JOptionPane.showMessageDialog(this,
                "Admin passwords do not match!",
                "Password Mismatch",
                JOptionPane.WARNING_MESSAGE);
        }
        config.setAdminPassword(password);

        config.setAdminSshPublicKey(sshKeyArea.getText().trim());

        String ncPassword = new String(nextcloudPasswordField.getPassword());
        String ncConfirm = new String(nextcloudConfirmField.getPassword());
        if (!ncPassword.equals(ncConfirm)) {
            JOptionPane.showMessageDialog(this,
                "Nextcloud passwords do not match!",
                "Password Mismatch",
                JOptionPane.WARNING_MESSAGE);
        }
        config.setNextcloudAdminPassword(ncPassword);
    }
}
