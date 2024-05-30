# Detect & Correct API Gateway REST API stage if X-Ray tracing disabled

## Overview

We can user X-Ray to trace and analyze user requests as they travel through your Amazon API Gateway APIs to the underlying services.

This query trigger detects X-Ray tracing disabled API Gateway REST API stage and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `apigateway_rest_api_stage_if_xray_tracing_disabled_trigger_enabled` should be set to `true` as the default is `false`.
- `apigateway_rest_api_stage_if_xray_tracing_disabled_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `apigateway_rest_api_stage_if_xray_tracing_disabled_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"enable_xray_tracing"` to delete the snapshot).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```