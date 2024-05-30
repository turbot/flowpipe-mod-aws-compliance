# Detect & Correct API Gateway REST API stage if X-Ray tracing disabled

## Overview

We can user X-Ray to trace and analyze user requests as they travel through your Amazon API Gateway APIs to the underlying services.

This query trigger detects X-Ray tracing disabled API Gateway REST API stage and then either sends a notification or attempts to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_apigateway_rest_api_stage_if_xray_tracing_disabled pipeline](https://hub.flowpipe.io/mods/turbot/aws_thrifty/pipelines/aws_thrifty.pipeline.detect_and_correct_apigateway_rest_api_stage_if_xray_tracing_disabled)
- [detect_and_correct_apigateway_rest_api_stage_if_xray_tracing_disabled trigger](https://hub.flowpipe.io/mods/turbot/aws_thrifty/triggers/aws_thrifty.trigger.query.detect_and_correct_apigateway_rest_api_stage_if_xray_tracing_disabled)