# configure_env.py
# Parses the master config and writes the more detailed version for the install.

import os
import sys

# Add the nearby "code" directory to the module loading path
sys.path.insert(0, '.')

from SDPEnv import SDPException, SDPConfigException, SDPInstance, SDPConfig

def main():
    try:
        sdpconfig = SDPConfig()
        sdpconfig.process_config()
    except SDPException as e:
        print("ERROR: ", str(e))
        sys.exit(1)
    sys.exit(0)

if __name__ == '__main__':
    main()
