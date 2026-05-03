package nixgen.gui;

import nixgen.model.ConfigData;

import javax.swing.*;
import java.awt.*;
import java.util.TimeZone;
import java.util.Arrays;

/**
 * System settings panel (timezone, locale, flake URL).
 */
public class SystemPanel extends JPanel {
    private final ConfigData config;

    private final JComboBox<String> timezoneCombo;
    private final JComboBox<String> localeCombo;
    private final JComboBox<String> keymapCombo;
    private final JComboBox<String> phoneRegionCombo;
    private final JTextField flakeUrlField;

    private static final String[] COMMON_LOCALES = {
        "en_GB.UTF-8",
        "en_US.UTF-8",
        "de_DE.UTF-8",
        "fr_FR.UTF-8",
        "es_ES.UTF-8",
        "it_IT.UTF-8",
        "ja_JP.UTF-8",
        "zh_CN.UTF-8",
        "pt_BR.UTF-8",
        "ru_RU.UTF-8",
        "nl_NL.UTF-8",
        "pl_PL.UTF-8"
    };

    private static final String[] COMMON_KEYMAPS = {
        "uk", "us", "de", "fr", "es", "it", "jp", "cn", "br", "ru"
    };

    private static final String[] PHONE_REGIONS = {
        "GB", "US", "DE", "FR", "ES", "IT", "JP", "CN", "BR", "RU", "NL", "PL", "AU", "CA"
    };

    public SystemPanel(ConfigData config) {
        this.config = config;

        setLayout(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(5, 10, 5, 10);
        gbc.fill = GridBagConstraints.HORIZONTAL;
        gbc.anchor = GridBagConstraints.WEST;

        int row = 0;

        // Timezone
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Timezone:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        String[] timezones = TimeZone.getAvailableIDs();
        Arrays.sort(timezones);
        timezoneCombo = new JComboBox<>(timezones);
        timezoneCombo.setSelectedItem(config.getTimezone());
        timezoneCombo.setEditable(true);
        add(timezoneCombo, gbc);
        row++;

        // Locale
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Locale:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        localeCombo = new JComboBox<>(COMMON_LOCALES);
        localeCombo.setSelectedItem(config.getLocale());
        localeCombo.setEditable(true);
        add(localeCombo, gbc);
        row++;

        // Console Keymap
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Console Keymap:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        keymapCombo = new JComboBox<>(COMMON_KEYMAPS);
        keymapCombo.setSelectedItem(config.getConsoleKeymap());
        keymapCombo.setEditable(true);
        add(keymapCombo, gbc);
        row++;

        // Phone Region (for Nextcloud)
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weightx = 0;
        add(new JLabel("Phone Region:"), gbc);
        gbc.gridx = 1;
        gbc.weightx = 1;
        phoneRegionCombo = new JComboBox<>(PHONE_REGIONS);
        phoneRegionCombo.setSelectedItem(config.getPhoneRegion());
        phoneRegionCombo.setEditable(true);
        add(phoneRegionCombo, gbc);
        gbc.gridx = 2;
        gbc.weightx = 0;
        add(new JLabel("(ISO 3166-1 alpha-2)"), gbc);
        row++;

        // Spacer
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 3;
        add(Box.createVerticalStrut(20), gbc);
        row++;

        // GitHub Flake URL
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.gridwidth = 1;
        gbc.weightx = 0;
        add(new JLabel("GitHub Flake URL:"), gbc);
        gbc.gridx = 1;
        gbc.gridwidth = 2;
        gbc.weightx = 1;
        flakeUrlField = new JTextField(30);
        add(flakeUrlField, gbc);
        row++;

        // Flake URL hint
        gbc.gridx = 1;
        gbc.gridy = row;
        gbc.gridwidth = 2;
        JLabel hintLabel = new JLabel("<html><i>e.g., github:username/repo#hostname<br/>Leave empty to use default format.</i></html>");
        hintLabel.setForeground(Color.GRAY);
        add(hintLabel, gbc);
        row++;

        // Filler
        gbc.gridx = 0;
        gbc.gridy = row;
        gbc.weighty = 1;
        gbc.gridwidth = 3;
        add(new JPanel(), gbc);
    }

    public void updateConfig() {
        config.setTimezone((String) timezoneCombo.getSelectedItem());
        config.setLocale((String) localeCombo.getSelectedItem());
        config.setConsoleKeymap((String) keymapCombo.getSelectedItem());
        config.setPhoneRegion((String) phoneRegionCombo.getSelectedItem());
        config.setGithubFlakeUrl(flakeUrlField.getText().trim());
    }
}
