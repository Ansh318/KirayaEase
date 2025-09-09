import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:kyc_workflow/digio_config.dart';
import 'package:kyc_workflow/environment.dart';
import 'package:kyc_workflow/gateway_event.dart';
import 'package:kyc_workflow/kyc_workflow.dart';
import 'package:kyc_workflow/service_mode.dart';

/// Runs the Digio KYC workflow and returns the result as a string.
/// Throws on platform failure.
Future<String> startKycWorkflow({
  required String customerId,
  required String emailOrPhone, // replace with whichever identifier needed
  required String nameOrOtherId, // e.g., name or txn id
  Map<String, String>? additionalData,
  bool sandbox = false,
}) async {
  String workflowResult;
  try {
    final config = DigioConfig();
    config.theme.primaryColor = "#32a83a";
    config.logo = "assets/logo.png";
    config.environment = Environment.SANDBOX;
    config.serviceMode =
        ServiceMode.OTP; // change to FACE / IRIS / FP as needed

    final plugin = KycWorkflow(config);
    plugin.setGatewayEventListener((GatewayEvent? e) {
      print("Gateway event: ${e?.event}");
    });

    final data = HashMap<String, String>();
    if (additionalData != null) {
      data.addAll(additionalData);
    }

    final result = await plugin.start(
      customerId,
      emailOrPhone,
      nameOrOtherId,
      data,
    );
    workflowResult = result.toString();
  } on PlatformException catch (e) {
    workflowResult = 'Platform exception: $e';
  } catch (e) {
    workflowResult = 'Unknown error: $e';
  }

  return workflowResult;
}
