package nixgen.gui;

import javax.swing.*;
import java.awt.*;
import java.io.File;

/**
 * Output directory selection and generate button panel.
 */
public class OutputPanel extends JPanel {
    private final Runnable generateAction;
    private File outputDirectory;
    private final JTextField directoryField;

    public OutputPanel(Runnable generateAction) {
        this.generateAction = generateAction;

        setLayout(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(10, 10, 10, 10);

        int row = 0;

        // Title
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 3;
        gbc.anchor = GridBagConstraints.CENTER;
        JLabel titleLabel = new JLabel("Generate NixOS Configuration");
        titleLabel.setFont(titleLabel.getFont().deriveFont(Font.BOLD, 16f));
        add(titleLabel, gbc);
        row++;

        // Spacer
        gbc.gridy = row;
        add(Box.createVerticalStrut(20), gbc);
        row++;

        // Output directory selection
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 1;
        gbc.anchor = GridBagConstraints.WEST;
        gbc.fill = GridBagConstraints.NONE;
        add(new JLabel("Output Directory:"), gbc);

        gbc.gridx = 1;
        gbc.fill = GridBagConstraints.HORIZONTAL;
        gbc.weightx = 1;
        directoryField = new JTextField(30);
        directoryField.setEditable(false);
        add(directoryField, gbc);

        gbc.gridx = 2;
        gbc.fill = GridBagConstraints.NONE;
        gbc.weightx = 0;
        JButton browseButton = new JButton("Browse...");
        browseButton.addActionListener(e -> selectDirectory());
        add(browseButton, gbc);
        row++;

        // Spacer
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 3;
        add(Box.createVerticalStrut(30), gbc);
        row++;

        // Generate button
        gbc.gridy = row;
        gbc.anchor = GridBagConstraints.CENTER;
        JButton generateButton = new JButton("Generate Configuration");
        generateButton.setFont(generateButton.getFont().deriveFont(Font.BOLD, 14f));
        generateButton.setPreferredSize(new Dimension(200, 40));
        generateButton.addActionListener(e -> generateAction.run());
        add(generateButton, gbc);
        row++;

        // Spacer
        gbc.gridy = row;
        add(Box.createVerticalStrut(30), gbc);
        row++;

        // Info text
        gbc.gridy = row;
        gbc.fill = GridBagConstraints.HORIZONTAL;
        JTextArea infoArea = new JTextArea();
        infoArea.setText(
            "The generator will create:\n\n" +
            "  - flake.nix                        Main flake configuration\n" +
            "  - .sops.yaml                       SOPS key configuration\n" +
            "  - hosts/{hostname}/                Host-specific configs\n" +
            "  - modules/                         NixOS modules\n" +
            "  - secrets/secrets.yaml             Encrypted secrets\n" +
            "  - keys/                            SSH and age keys\n\n" +
            "IMPORTANT:\n" +
            "  - Keep the keys/ directory secure!\n" +
            "  - Copy keys/age_key.txt to ~/.config/sops/age/keys.txt\n" +
            "  - Copy keys/ssh_host_ed25519_key* to target server's /etc/ssh/"
        );
        infoArea.setEditable(false);
        infoArea.setOpaque(false);
        infoArea.setFont(new Font(Font.MONOSPACED, Font.PLAIN, 12));
        add(infoArea, gbc);
        row++;

        // Filler
        gbc.gridy = row;
        gbc.weighty = 1;
        add(new JPanel(), gbc);
    }

    private void selectDirectory() {
        JFileChooser chooser = new JFileChooser();
        chooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
        chooser.setDialogTitle("Select Output Directory");

        if (outputDirectory != null) {
            chooser.setCurrentDirectory(outputDirectory.getParentFile());
        }

        int result = chooser.showOpenDialog(this);
        if (result == JFileChooser.APPROVE_OPTION) {
            outputDirectory = chooser.getSelectedFile();
            directoryField.setText(outputDirectory.getAbsolutePath());
        }
    }

    public File getOutputDirectory() {
        return outputDirectory;
    }
}
