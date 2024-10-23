# AWS Compliance Mod for Flowpipe

Pipelines to detect and remediate misconfigurations in AWS resources.

## Documentation

- **[Pipelines →](https://hub.flowpipe.io/mods/turbot/aws_compliance/pipelines)**

## Getting Started

### Requirements

Docker daemon must be installed and running. Please see [Install Docker Engine](https://docs.docker.com/engine/install/) for more information.

### Installation

Download and install Flowpipe (https://flowpipe.io/downloads) and Steampipe (https://steampipe.io/downloads). Or use Brew:

```sh
brew install turbot/tap/flowpipe
brew install turbot/tap/steampipe
```

Install the AWS plugin with [Steampipe](https://steampipe.io):

```sh
steampipe plugin install aws
```

Steampipe will automatically use your default AWS credentials. Optionally, you can [setup multiple accounts](https://hub.steampipe.io/plugins/turbot/aws#multi-account-connections) or [customize AWS credentials](https://hub.steampipe.io/plugins/turbot/aws#configuring-aws-credentials).

Create a `connection_import` resource to import your Steampipe AWS connections:

```sh
vi ~/.flowpipe/config/aws.fpc
```

```hcl
connection_import "aws" {
  source      = "~/.steampipe/config/aws.spc"
  connections = ["*"]
}
```

For more information on importing connections, please see [Connection Import](https://flowpipe.io/docs/reference/config-files/connection_import).

For more information on connections in Flowpipe, please see [Managing Connections](https://flowpipe.io/docs/run/connections).

Clone the mod:

```sh
mkdir aws-compliance
cd aws-compliance
git clone git@github.com:turbot/flowpipe-mod-aws-compliance.git
```

Install the dependencies:

```sh
flowpipe mod install
```

### Running Detect and Correct Pipelines

To run your first detection, you'll need to ensure your Steampipe server is up and running:

```sh
steampipe service start
```

To find your desired detection, you can filter the `pipeline list` output:

```sh
flowpipe pipeline list | grep "detect_and_correct"
```

Then run your chosen pipeline:

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_block_public_access_disabled
```

This will then run the pipeline and depending on your configured running mode; perform the relevant action(s), there are 3 running modes:
- Wizard
- Notify
- Automatic

#### Wizard

This is the `default` running mode, allowing for a hands-on approach to approving changes to resources by prompting for [input](https://flowpipe.io/docs/build/input) for each detected resource.

Whilst the out of the box default is to run the workflow directly in the terminal. You can use Flowpipe [server](https://flowpipe.io/docs/run/server) and [external integrations](https://flowpipe.io/docs/build/input#create-an-integration) to prompt in `http`, `slack`, `teams`, etc.

#### Notify

This mode as the name implies is used purely to report detections via notifications either directly to your terminal when running in client mode or via another configured [notifier](https://flowpipe.io/docs/reference/config-files/notifier) when running in server mode for each detected resource.

To run in `notify` mode, you will need to set the `approvers` variable to an empty list `[]` and ensure the resource-specific `default_action` variable is set to `notify`, either in your `flowpipe.fpvars` file:

```hcl
approvers = []
s3_buckets_with_block_public_access_disabled_default_action = "notify"
```

or pass the `approvers` and `default_action` arguments on the command-line.

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_block_public_access_disabled --arg='default_action=notify' --arg='approvers=[]'
```

#### Automatic

This behavior allows for a hands-off approach to remediating resources.

To run in `automatic` mode, you will need to set the `approvers` variable to an empty list `[]` and the the resource-specific `default_action` variable to one of the available options in your `flowpipe.fpvars` file:

```hcl
approvers = []
s3_buckets_with_block_public_access_disabled_default_action = "block_public_access"
```

or pass the `approvers` and `default_action` argument on the command-line.

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_block_public_access_disabled --arg='approvers=[] --arg='default_action=block_public_access'
```

To further enhance this approach, you can enable the pipelines corresponding [query trigger](#running-query-triggers) to run completely hands-off.

### Running Query Triggers

> Note: Query triggers require Flowpipe running in [server](https://flowpipe.io/docs/run/server) mode.

Each `detect_and_correct` pipeline comes with a corresponding [Query Trigger](https://flowpipe.io/docs/flowpipe-hcl/trigger/query), these are _disabled_ by default allowing for you to _enable_ and _schedule_ them as desired.

Let's begin by looking at how to set-up a Query Trigger to automatically resolve our S3 buckets that do not block public access.

Firsty, we need to update our `flowpipe.fpvars` file to add or update the following variables - if we want to run our remediation `hourly` and automatically `apply` the corrections:

```hcl
s3_buckets_with_block_public_access_disabled_trigger_enabled  = true
s3_buckets_with_block_public_access_disabled_trigger_schedule = "1h"
s3_buckets_with_block_public_access_disabled_default_action   = "block_public_access"
```

Now we'll need to start up our Flowpipe server:

```sh
flowpipe server
```

This will run every hour and detect S3 buckets that do not block public access and apply the corrections without further interaction!

### Configure Variables

Several pipelines have [input variables](https://flowpipe.io/docs/build/mod-variables#input-variables) that can be configured to better match your environment and requirements.

Each variable has a default defined in its source file, e.g, `s3/s3_buckets_with_default_encryption_disabled.fp` (or `variables.fp` for more generic variables), but these can be overwritten in several ways:

The easiest approach is to setup your `flowpipe.fpvars` file, starting with the sample:

```sh
cp flowpipe.fpvars.example flowpipe.fpvars
vi flowpipe.fpvars

flowpipe pipeline run detect_and_correct_s3_buckets_with_block_public_access_disabled
```

Alternatively, you can pass variables on the command line:

```sh
flowpipe pipeline run detect_and_correct_s3_buckets_with_block_public_access_disabled --var notifier=notifier.default
```

Or through environment variables:

```sh
export FP_VAR_notifier="notifier.default"
flowpipe pipeline run detect_and_correct_s3_buckets_with_block_public_access_disabled
```

For more information, please see [Passing Input Variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)

Finally, each detection pipeline has a corresponding [Query Trigger](https://flowpipe.io/docs/flowpipe-hcl/trigger/query), these are disabled by default allowing for you to configure only those which are required, see the [docs](https://hub.flowpipe.io/mods/turbot/aws_compliance/triggers) for more information.

## Open Source & Contributing

This repository is published under the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0). Please see our [code of conduct](https://github.com/turbot/.github/blob/main/CODE_OF_CONDUCT.md). We look forward to collaborating with you!

[Flowpipe](https://flowpipe.io) and [Steampipe](https://steampipe.io) are products produced from this open source software, exclusively by [Turbot HQ, Inc](https://turbot.com). They are distributed under our commercial terms. Others are allowed to make their own distribution of the software, but cannot use any of the Turbot trademarks, cloud services, etc. You can learn more in our [Open Source FAQ](https://turbot.com/open-source).

## Get Involved

**[Join #flowpipe on Slack →](https://turbot.com/community/join)**

Want to help but don't know where to start? Pick up one of the `help wanted` issues:

- [Flowpipe](https://github.com/turbot/flowpipe/labels/help%20wanted)
- [AWS Compliance Mod](https://github.com/turbot/flowpipe-mod-aws-compliance/labels/help%20wanted)
