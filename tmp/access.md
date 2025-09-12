
# Workshop Studio Access Instructions

To access your AWS account follow the instructions below. Five attendees can access each AWS event.

1. Browse to https://catalog.workshops.aws/ and click **Get Started**

<p>

2. You will be prompted to sign in. Select the option **Email One-Time Password(OTP)**

    ![Workshop Studio sign in](/tmp/img/wssignin.png)

3. Enter your email address and click **Send passcode**. When the email arrives you can enter the passcode and log-in

<p>

4. Your instructor will provide you with an **event access code**. Enter the provided hash into the text box and click **Next**

<p>

5. Click **Open AWS console** to access your dedicated AWS account.

    ![Access AWS Account](/tmp/img/access-account.png)

5. In the AWS Console, browse to **CloudFormation**

    ![browse to CloudFormation](/tmp/img/browse-cloudformation.png)

6. Select your stack name and click the **Outputs** tab

    ![CloudFormation outputs tab](/tmp/img/stack-output.png)

7. Open a new browser tab and enter the URL found in the CloudFormation outputs under `01CodeServerURL`. You will be prompted for a password

    ![code-server login box](/tmp/img/code-server-login.png)

8. Open the `02CodeServerPassword` CloudFormation output in a new tab and select **Retrieve secret value** to view the password

    ![retrieve secret button](/tmp/img/retrieve-secret.png)

9. Use the password to log into code-server. Select **File > Open Folder** and open the `/home/ec2-user/workspace/my-workspace` folder. Accept the message about trusting authors

    ![accept code-server trust message](/tmp/img/trust-authors.png) 

10. The Explorer pane will show a git repository. Open a terminal by selecting **Terminal** from the top menu, then click **New Terminal**

    ![code-server terminal layout](/tmp/img/terminal-layout.png)

11. Navigate to workspace: `cd /home/ec2-user/workspace/my-workspace`

<p>

12. Set the default agent: `q settings chat.defaultAgent platform-engineer`

13. Start Amazon Q Developer CLI with `q chat -a`

<p>

14. Use `/model` to select AI model, `/tools` to see available MCP tools

<p>

15. Use Amazon Q CLI to accelerate your development 🚀

<p>

16. Learn about development environment features [here](https://github.com/aws-samples/sample-developer-environment)

<p>

17. Browse [AWS Labs MCP](https://github.com/awslabs/mcp) for additional MCP servers

<p>

18. Add more tools by editing `/home/ec2-user/workspace/my-workspace/.amazonq/mcp.json`

> *Note: Don't worry if you accidentally close your browser - when you log back in, everything will be right where you left it.*