## Publish node_modules to Nexus
Publishes all non-private packages from `node_modules` to a Nexus npm registry.

### Requirements
- Node.js
- npm
- Nexus npm registry access

### Environment Variables
```bash
export NEXUS_REGISTRY="http://localhost:8081/repository/npm-internal/"
export NEXUS_AUTH_TOKEN="your-npm-token"
```

### Usage
```bash
bash publish-node-modules-to-nexus.sh
```

### Dry Run
```bash
DRY_RUN=true bash publish-node-modules-to-nexus.sh
```

### Notes
- Skips private packages
- Skips already published versions
- Uses npm pack + npm publish
- Does not run lifecycle scripts
