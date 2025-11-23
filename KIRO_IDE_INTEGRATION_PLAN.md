# Kiro IDE Integration Plan with NICE DCV

## Overview
Add optional Kiro IDE deployment using NICE DCV (AWS's native remote desktop solution) **alongside** code-server, controlled by a CloudFormation parameter. When enabled, users get both environments accessible through the same CloudFront distribution.

## Architecture Decision: Additive Approach

**Strategy: Install Both When Enabled**
- `EnableKiroIDE=false` (default): Only code-server (existing behavior, zero changes)
- `EnableKiroIDE=true`: code-server + GNOME Desktop + NICE DCV + Kiro IDE

**Why NICE DCV:**
- AWS-native solution with official AL2023 support
- Better performance than VNC/noVNC
- Native clients for Windows, Mac, Linux + web browser access
- GPU acceleration support
- Free for EC2 use
- Port 8443 (HTTPS) by default

**Why GNOME Desktop:**
- AWS-recommended desktop environment for AL2023
- Officially tested with NICE DCV
- Default desktop manager (GDM) included
- Simple installation: `dnf groupinstall 'Desktop'`

**Access Pattern:**
- Port 8080: code-server (always available)
- Port 8443: NICE DCV with Kiro IDE (when EnableKiroIDE=true)

## CloudFormation Changes

### 1. New Parameter
```yaml
EnableKiroIDE:
  Type: String
  Default: false
  AllowedValues:
    - true
    - false
  Description: Enable Kiro IDE with NICE DCV remote desktop (requires x64/amd64 architecture)
```

**Note:** Kiro IDE is currently only available for x64/amd64 architecture. ARM64 support is under development but not yet released.

### 2. Parameter Group Update
Add `EnableKiroIDE` to "Deployment Settings" parameter group

### 3. New Condition
```yaml
Conditions:
  EnableKiroIDE: !Equals [!Ref EnableKiroIDE, "true"]
  UseX64: !Equals [!Ref InstanceArchitecture, "x86_64"]
  InstallKiroIDE: !And
    - !Condition EnableKiroIDE
    - !Condition UseX64
```

**Note:** `InstallKiroIDE` condition ensures Kiro IDE resources are only created when both EnableKiroIDE is true AND architecture is x64.

### 4. New Validation Rule
```yaml
Rules:
  KiroIDEArchitectureCheck:
    RuleCondition: !Equals [!Ref EnableKiroIDE, "true"]
    Assertions:
      - Assert: !Equals [!Ref InstanceArchitecture, "x86_64"]
        AssertDescription: "Kiro IDE requires x64/amd64 architecture. Please select an x64 instance type or disable Kiro IDE."
```

**Note:** This rule validates parameter combinations at stack creation time and provides a clear error message if incompatible options are selected.

### 4. Security Group Changes

**Current:** `securitygroupcodeserver` allows port 8080 from ALB

**New:** Add conditional port 8443 ingress rule
```yaml
securitygroupingressdcv:
  Type: AWS::EC2::SecurityGroupIngress
  Condition: InstallKiroIDE
  Properties:
    GroupId: !Ref securitygroupcodeserver
    IpProtocol: tcp
    FromPort: 8443
    ToPort: 8443
    SourceSecurityGroupId: !Ref securitygroupalb
    Description: Allow inbound from ALB to NICE DCV
```

**ALB Security Group:** Add conditional egress rule for port 8443

### 5. ALB Target Group Changes

**Current:** `albtargetgroupcodeserver` targets port 8080

**New:** Add second target group for NICE DCV (conditional)
```yaml
albtargetgroupdcv:
  Type: AWS::ElasticLoadBalancingV2::TargetGroup
  Condition: InstallKiroIDE
  Properties:
    HealthCheckPath: /
    HealthCheckPort: 8443
    HealthCheckProtocol: HTTPS
    Name: !Sub ${PrefixCode}-targetgroup-dcv
    Port: 8443
    Protocol: HTTPS
    TargetType: instance
    Targets:
      - Id: !Ref ec2codeserver
    VpcId: !Ref vpc01
```

**Note:** Keep existing code-server target group unchanged

### 6. ALB Listener Changes

**Current:** HTTP listener on port 80 with rule for code-server

**New:** Add second listener rule for NICE DCV (conditional)
```yaml
alblistenerruledcv:
  Type: AWS::ElasticLoadBalancingV2::ListenerRule
  Condition: InstallKiroIDE
  Properties:
    Actions:
      - Type: forward
        TargetGroupArn: !Ref albtargetgroupdcv
    Conditions:
      - Field: http-header
        HttpHeaderConfig:
          HttpHeaderName: !Sub "{{resolve:secretsmanager:${cloudfrontsecretheadercodeserver}:SecretString:HeaderName}}"
          Values:
            - !Sub "{{resolve:secretsmanager:${cloudfrontsecretheadercodeserver}:SecretString:HeaderValue}}"
      - Field: path-pattern
        PathPatternConfig:
          Values:
            - "/dcv*"
    ListenerArn: !Ref alblistenercodeserver
    Priority: 5
```

**Note:** Keep existing code-server listener rule at priority 10

### 7. CloudFront Changes

**Current:** CloudFront → HTTP ALB → HTTP code-server

**New:** Add second cache behavior for DCV path (conditional)
```yaml
cloudfrontdistributioncodeserver:
  Properties:
    DistributionConfig:
      # Existing default behavior for code-server unchanged
      DefaultCacheBehavior:
        # ... existing config ...
      
      # Add conditional cache behavior for DCV
      CacheBehaviors: !If
        - InstallKiroIDE
        - - PathPattern: "/dcv*"
            AllowedMethods: [GET, HEAD, OPTIONS, PUT, PATCH, POST, DELETE]
            CachePolicyId: !Ref cloudfrontcachepolcodeserver
            OriginRequestPolicyId: 216adef6-5c7f-47e4-b989-5492eafa07d3
            TargetOriginId: CodeServerOrigin
            ViewerProtocolPolicy: redirect-to-https
        - !Ref AWS::NoValue
```

**Note:** Both paths use same origin (ALB), routing handled by ALB listener rules

### 8. Instance Type Parameter Update

**Current Description:**
```
EC2 instance type MUST match architecture. amd64= t3.small, t3a.large, c6i.xlarge, m6a.2xlarge, etc. arm64= t4g.large, c7g.xlarge, m6g.2xlarge, etc.Template will fail if mismatched.
```

**New Description:**
```
EC2 instance type MUST match architecture. amd64= t3a.large, etc. arm64= t4g.large, etc. Note: Kiro IDE requires amd64 architecture (recommend t3a.xlarge or larger).
```

### 9. Secret Management

**Current:** `secretcodeserver` for code-server password

**New:** Reuse same secret for both services
- code-server: Uses password from secret (existing)
- NICE DCV: Uses same password for ec2-user session authentication

**No changes needed** - both services read from same secret

### 10. EC2 UserData Changes

**Current:** Downloads and runs `devbox-setup.sh`, already exports `INSTANCE_ARCHITECTURE`

**New:** Add `EnableKiroIDE` parameter to environment file
```yaml
UserData:
  Fn::Base64: !Sub |
    # ... existing code ...
    export ENABLE_KIRO_IDE="${EnableKiroIDE}"
    export INSTANCE_ARCHITECTURE="${InstanceArchitecture}"  # Already exists
    # ... rest of script ...
```

## devbox-setup.sh Changes

### 1. New Environment Variable
```bash
export ENABLE_KIRO_IDE="${EnableKiroIDE}"  # From CloudFormation
```

### 2. Conditional Installation Logic

```bash
# Always install code-server (existing logic)
install_component "code_server_installed" '...'

# Conditionally install Kiro IDE stack (x64 only)
if [ "${ENABLE_KIRO_IDE}" = "true" ] && [ "${INSTANCE_ARCHITECTURE}" = "x86_64" ]; then
    install_component "desktop_installed" '...'
    install_component "nice_dcv_installed" '...'
    install_component "kiro_ide_installed" '...'
elif [ "${ENABLE_KIRO_IDE}" = "true" ]; then
    echo "WARNING: Kiro IDE requires x64/amd64 architecture. Skipping Kiro IDE installation."
fi
```

### 3. Desktop Environment Installation

**Component:** `desktop_installed`

**AWS Official AL2023 Installation:**
```bash
install_component "desktop_installed" '
# Install GNOME Desktop
dnf groupinstall -y "Desktop"

# Update packages
dnf upgrade -y

# Configure GDM to auto-start
systemctl set-default graphical.target

# Disable GNOME initial setup wizard
mkdir -p /home/ec2-user/.config
touch /home/ec2-user/.config/gnome-initial-setup-done
chown -R ec2-user:ec2-user /home/ec2-user/.config
' "Failed to install desktop environment"
```

**Reference:** [AWS DCV Prerequisites for AL2023](https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-prereq.html)

### 4. NICE DCV Installation

**Component:** `nice_dcv_installed`

```bash
install_component "nice_dcv_installed" '
# Install NICE DCV server from AL2023 repos
dnf install -y nice-dcv-server nice-dcv-web-viewer

# Configure DCV
cat > /etc/dcv/dcv.conf << EOF
[license]
[log]
level=info
[session-management]
create-session=true
[session-management/defaults]
[session-management/automatic-console-session]
owner=ec2-user
[display]
[connectivity]
enable-quic-frontend=true
[security]
authentication=system
EOF

# Enable and start DCV server
systemctl enable dcvserver
systemctl start dcvserver

# Create DCV session for ec2-user
dcv create-session --owner ec2-user --type console ec2-user-session
' "Failed to install NICE DCV"
```

### 5. Kiro IDE Installation

**Component:** `kiro_ide_installed`

**Architecture Support:** x64/amd64 only. ARM64 support is under development but not yet publicly available.

```bash
install_component "kiro_ide_installed" '
# Verify architecture (defense in depth)
ARCH=$(detect_architecture)
if [ "$ARCH" != "x86_64" ]; then
    echo "ERROR: Kiro IDE requires x64/amd64 architecture. Current: $ARCH"
    exit 1
fi

# Get latest version from metadata endpoint
VERSION=$(curl -s https://prod.download.desktop.kiro.dev/stable/metadata-linux-x64-stable.json | jq -r .currentRelease)

# Download and extract
curl -o /tmp/kiro-ide.tar.gz "https://prod.download.desktop.kiro.dev/releases/stable/linux-x64/signed/$VERSION/tar/kiro-ide-$VERSION-stable-linux-x64.tar.gz"
tar -xzf /tmp/kiro-ide.tar.gz -C /opt/
rm /tmp/kiro-ide.tar.gz

# Create desktop shortcut
mkdir -p /home/ec2-user/Desktop
cat > /home/ec2-user/Desktop/kiro-ide.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Kiro IDE
Exec=/opt/kiro-ide/kiro-ide
Icon=/opt/kiro-ide/resources/app/icon.png
Terminal=false
Categories=Development;IDE;
EOF

chmod +x /home/ec2-user/Desktop/kiro-ide.desktop
chown -R ec2-user:ec2-user /home/ec2-user/Desktop

# Set permissions
chown -R ec2-user:ec2-user /opt/kiro-ide
' "Failed to install Kiro IDE"
```

**Installation Method:**
- Uses official metadata endpoint to get latest version dynamically
- Downloads from AWS S3 bucket: `prod.download.desktop.kiro.dev`
- Extracts to `/opt/kiro-ide`
- Creates GNOME desktop shortcut for easy access
- **x64 only** - CloudFormation Rules prevent ARM64 deployment with EnableKiroIDE=true

## Output Changes

### Current Outputs
```yaml
01CodeServerURL: CloudFront URL
02CodeServerPassword: Secrets Manager link
```

### New Outputs (Additive)
```yaml
01CodeServerURL:
  Description: URL to access code-server through CloudFront
  Value: !Sub https://${cloudfrontdistributioncodeserver.DomainName}

02CodeServerPassword:
  Description: Retrieve your code-server password from AWS Secrets Manager
  Value: !Sub https://${AWS::Region}.console.aws.amazon.com/secretsmanager/secret?name=${secretcodeserver}

03KiroIDEURL:
  Condition: InstallKiroIDE
  Description: URL to access Kiro IDE through NICE DCV. Download native client from https://download.nice-dcv.com/ or use web browser. Username: ec2-user, Password: same as code-server (from Secrets Manager)
  Value: !Sub https://${cloudfrontdistributioncodeserver.DomainName}/dcv
```

## Resource Naming

**No renaming needed** - keep existing resource names:
- `securitygroupcodeserver` - now handles both services
- `albtargetgroupcodeserver` - existing for code-server
- `albtargetgroupdcv` - new for NICE DCV (conditional)
- `ec2codeserver` - now runs both services when enabled

**Rationale:** Backward compatibility and minimal changes to existing infrastructure

## Implementation Phases

### Phase 1: CloudFormation Template Updates
1. Add `EnableKiroIDE` parameter
2. Add `UseKiroIDE` and `UseCodeServer` conditions
3. Update security group with conditional rules
4. Update ALB target group with conditional ports
5. Update CloudFront origin with conditional protocol
6. Update outputs with conditional descriptions
7. Pass `ENABLE_KIRO_IDE` to UserData environment

### Phase 2: devbox-setup.sh Updates
1. Add conditional installation logic
2. Implement `desktop_installed` component
3. Implement `nice_dcv_installed` component
4. Implement `kiro_ide_installed` component
5. Test installation flow

### Phase 3: Documentation Updates
1. Update README.md with Kiro IDE option
2. Add NICE DCV client download instructions
3. Add architecture diagram showing both modes
4. Update security considerations for NICE DCV

## Testing Checklist

### EnableKiroIDE=false (Default - Existing Behavior)
- [ ] Stack deploys successfully on x64
- [ ] Stack deploys successfully on ARM64
- [ ] CloudFront URL accessible
- [ ] code-server loads correctly
- [ ] Workspace initialized properly
- [ ] Git/S3 integration works
- [ ] Pipeline triggers (if enabled)
- [ ] No DCV resources created
- [ ] No desktop environment installed

### EnableKiroIDE=true + x64 (New Feature)
- [ ] Stack deploys successfully
- [ ] code-server still accessible at main URL
- [ ] NICE DCV accessible at `/dcv` path
- [ ] Desktop environment loads
- [ ] Kiro IDE launches from desktop
- [ ] Both environments access same workspace
- [ ] Git/S3 integration works in both
- [ ] AWS credentials work in both (developer profile)
- [ ] MCP servers accessible in Kiro IDE
- [ ] Can switch between code-server and Kiro IDE

### EnableKiroIDE=true + ARM64 (Validation Test)
- [ ] Stack creation fails with clear error message
- [ ] Error message indicates x64 requirement
- [ ] CloudFormation Rules block deployment before resource creation

### Upgrade Path (false → true on x64)
- [ ] Existing stack updates successfully
- [ ] code-server continues working during update
- [ ] DCV becomes available after update
- [ ] Workspace data preserved

## Security Considerations

### NICE DCV Security
- Uses HTTPS by default (port 8443)
- System authentication (Linux user passwords)
- Session encryption
- CloudFront still provides DDoS protection
- Origin verification header still applies

### Additional Recommendations
1. Consider adding IP allowlist for DCV access
2. Enable MFA for IAM users accessing the environment
3. Use AWS Systems Manager Session Manager for SSH access
4. Enable CloudTrail for API activity monitoring

## Cost Implications

### Additional Costs with Kiro IDE
- **Instance Size:** Recommend larger instance for GNOME Desktop
  - t4g.large (8GB): $0.0672/hr = ~$49/month (current default, minimum)
  - t4g.xlarge (16GB): $0.1344/hr = ~$98/month (recommended, +$49/month)
  - t4g.2xlarge (32GB): $0.2688/hr = ~$196/month (optimal, +$147/month)
- **Data Transfer:** NICE DCV may use more bandwidth than code-server
  - Estimate: +20-30% data transfer costs
- **Storage:** GNOME Desktop adds ~3-4GB to EBS volume (minimal cost)

### No Additional Costs
- NICE DCV server license (free for EC2)
- Kiro IDE (free download)
- CloudFront/ALB (same usage pattern)

### Cost Optimization
- Users can keep `EnableKiroIDE=false` to avoid desktop overhead
- code-server remains lightweight option on t4g.large

## Migration Path

### Existing Deployments
Users with existing code-server deployments:
1. **No action needed** - default `EnableKiroIDE=false` maintains current behavior
2. **To add Kiro IDE:** Update stack with `EnableKiroIDE=true`
   - CloudFormation adds new resources (security group rules, target group, listener rule)
   - EC2 instance installs desktop + DCV + Kiro IDE on next boot
   - code-server continues working unchanged
   - Workspace data preserved (same S3 git bucket)

### Rollback
Set `EnableKiroIDE=false` to remove DCV resources (desktop environment remains installed but inactive)

## Open Questions

1. **Path-based routing:** Use `/dcv` path or different approach?
   - **Recommendation:** `/dcv*` path pattern on ALB listener rule
   
2. **Desktop Environment:** ✅ **RESOLVED** - Use GNOME Desktop (AWS-recommended for AL2023)
   - Command: `dnf groupinstall 'Desktop'`
   - Includes GDM display manager
   - Officially tested with NICE DCV

3. **DCV Session Management:** Auto-create session vs manual?
   - **Recommendation:** Auto-create console session for ec2-user

4. **Kiro IDE Version:** Pin version or use latest?
   - **Recommendation:** Use latest, add parameter for version pinning later

5. **HTTPS Handling:** ALB terminates HTTPS or pass through to DCV?
   - **Recommendation:** ALB uses HTTP, DCV handles HTTPS internally (port 8443)

6. **Instance Size:** Should we change default instance type when EnableKiroIDE=true?
   - **Recommendation:** Keep t4g.large default, add warning in parameter description about t4g.xlarge for better performance

## Next Steps

1. Review and approve this plan
2. Create feature branch
3. Implement Phase 1 (CloudFormation changes)
4. Implement Phase 2 (devbox-setup.sh changes)
5. Test both modes thoroughly
6. Update documentation
7. Submit PR for review
