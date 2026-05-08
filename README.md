# NixOS Home Server

NixOS is a hard OS to use. The barrier to entry is very high.

I have created a Secure NixOS config in ./ActiveConfig
It uses a reverse proxy, fail2ban, sops secrets among other things.

I currently have a config generator in ./NixConfigGenerator that produces a full config based on the secure one.
It takes user input and generates the config with their settings in mind.

The result is in ./TestConfig

I have a new idea however

# New Idea

In ./Barnfold, there is another config similar to ActiveConfig but with some key differences.
There is now an /options directory containing all the information unique to the user like SSH pub key, hostname etc

Instead of a Python config generator, let's create a graphical Python program that produces only the options.nix file as well as giving instructions on how to set up the host key as well as the sops secret.

# How it works

1. Users clone the project. The project contains a flake functionally identical to Barnfold but without user's options.
2. Users run the Python graphical program and it walks them through filling in all information and where to get this information.
3. With their new edited flake, users first deploy it publicly to their GitHub account. Thanks to sops and hashes, all passwords are encrypted.
4. Users use NixOS-anywhere to deploy to the target machine. In my demonstration, the target machine will be running Ubuntu Graphical
5. The initial rebuild will fail. Users will then need to finally configure their age-keys
6. Users rebuild again and finally the config should work instantly.

# Your tasks

1. Re-write the Python program to instead produce just the contents of the /options directory similar to Barnfold
2. Add instructions walking through the entire installation process
3. Reformat the entire repository so there is the initial flake, template options directory, a directory for the python project
4. Update the README.md will full documentation of the process of design, development and implementation.