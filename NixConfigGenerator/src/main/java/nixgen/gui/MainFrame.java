package nixgen.gui;

import nixgen.generator.ConfigGenerator;
import nixgen.model.ConfigData;

import javax.swing.*;
import java.awt.*;
import java.io.File;

/**
 * Main application window with tabbed interface.
 */
public class MainFrame extends JFrame {
    private final ConfigData config;
    private final NetworkPanel networkPanel;
    private final UserPanel userPanel;
    private final SystemPanel systemPanel;
    private final OutputPanel outputPanel;

    public MainFrame() {
        super("NixOS Config Generator");
        this.config = new ConfigData();

        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setSize(700, 550);
        setLocationRelativeTo(null);

        // Create panels
        networkPanel = new NetworkPanel(config);
        userPanel = new UserPanel(config);
        systemPanel = new SystemPanel(config);
        outputPanel = new OutputPanel(this::generateConfig);

        // Create tabbed pane
        JTabbedPane tabbedPane = new JTabbedPane();
        tabbedPane.addTab("Network", networkPanel);
        tabbedPane.addTab("User", userPanel);
        tabbedPane.addTab("System", systemPanel);
        tabbedPane.addTab("Output", outputPanel);

        add(tabbedPane);
    }

    private void generateConfig() {
        // Update config from all panels
        networkPanel.updateConfig();
        userPanel.updateConfig();
        systemPanel.updateConfig();

        File outputDir = outputPanel.getOutputDirectory();
        if (outputDir == null) {
            JOptionPane.showMessageDialog(this,
                "Please select an output directory.",
                "Error",
                JOptionPane.ERROR_MESSAGE);
            return;
        }

        // Validate
        ConfigGenerator generator = new ConfigGenerator(config, outputDir);
        String errors = generator.validate();
        if (errors != null) {
            JOptionPane.showMessageDialog(this,
                "Please fix the following errors:\n\n" + errors,
                "Validation Error",
                JOptionPane.ERROR_MESSAGE);
            return;
        }

        // Generate
        try {
            generator.generate();

            String message = String.format(
                "Configuration generated successfully!\n\n" +
                "Output directory: %s\n\n" +
                "Generated keys:\n" +
                "- SSH host key: keys/ssh_host_ed25519_key\n" +
                "- Workstation age key: keys/age_key.txt\n\n" +
                "IMPORTANT: Keep the keys directory secure!\n" +
                "Copy age_key.txt to ~/.config/sops/age/keys.txt on your workstation.",
                outputDir.getAbsolutePath()
            );

            JOptionPane.showMessageDialog(this,
                message,
                "Success",
                JOptionPane.INFORMATION_MESSAGE);
        } catch (Exception e) {
            JOptionPane.showMessageDialog(this,
                "Error generating configuration:\n" + e.getMessage(),
                "Error",
                JOptionPane.ERROR_MESSAGE);
            e.printStackTrace();
        }
    }
}
