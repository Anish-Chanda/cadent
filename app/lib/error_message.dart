import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

SnackBar errorSnackBar(String message){
  return SnackBar(
    content: Text(message),
    backgroundColor: Colors.red,
  );
}

String simplifyErrorMessage(e){
  String simplified = "";
  switch(e.runtimeType){
    case DioException:
      simplified = "Could not connect to host.";
      break;
    case TimeoutException:
      simplified = "Request timed out.";
      break;
    default:
      simplified = e.toString();
      break;
  }
  return simplified;
}

