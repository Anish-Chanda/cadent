import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

SnackBar errorSnackBar(e, String defaultMessage, context){
  return SnackBar(
    content: Text(simplifyErrorMessage(e, defaultMessage)),
    backgroundColor: AppColors.errorRed,
    duration: Duration(seconds: 3),
  );
}
SnackBar warningSnackBar(String message, context){
  return SnackBar(
    content: Text(message),
    backgroundColor: AppColors.warningOrange,
    duration: Duration(seconds: 3),
  );
}
SnackBar successSnackBar(String message, context){
  return SnackBar(
    content: Text(message),
    backgroundColor: AppColors.successGreen,
    duration: Duration(seconds: 3),
  );
}

String simplifyErrorMessage(e, String defaultMessage){
    if(e is DioException) {
      log(
        'DioException caught',
        name: 'simplifyErrorMessage',
        error: e,
        stackTrace: e.stackTrace,
      );
      if(e.response != null){
        final statusCode = e.response?.statusCode;
        switch(statusCode){
          case 400:
            return "Bad request. Please check your input.";
          case 401:
            return "Unauthorized. Please log in again.";
          case 403:
            return "Access denied.";
          case 404:
            return "Requested resource not found.";
          case 500:
            return "Server error. Please try again later.";
          default:
            return "Unexpected server response. Please try again.";
        }
      }
      switch (e.type) {
        case DioExceptionType.connectionError:
          return "Could not connect to the server. Please check your internet connection.";
        case DioExceptionType.connectionTimeout:
          return "The request took too long. Please try again later.";
        case DioExceptionType.sendTimeout:
          return "The request could not be sent in time. Please try again.";
        case DioExceptionType.receiveTimeout:
          return "The server took too long to respond. Please try again later.";
        case DioExceptionType.badResponse:
          return "The server returned an unexpected response. Please try again later.";
        case DioExceptionType.badCertificate:
          return "Cannot verify the server's security certificate. Please check your internet connection or try again later.";
        case DioExceptionType.cancel:
          return "The request was cancelled.";
        default:
          return "An unexpected error occurred. Please try again.";
      }
    }else if(e is SocketException){
    log(
      'Error caught: $e',
      name: 'simplifyErrorMessage',
      error: e,
    );
    return "No internet connection. Please check your network and try again.";
  }else if(e is TimeoutException){
    log(
      'Error caught: $e',
      name: 'simplifyErrorMessage',
      error: e,
    );
    return "The request timed out. Please try again later.";
  }else if(e is FormatException){
    log(
      'Error caught: $e',
      name: 'simplifyErrorMessage',
      error: e,
    );
    return "Unexpected response format. Please try again later.";
  }else if(e is PlatformException){
    log(
      'Error caught: $e',
      name: 'simplifyErrorMessage',
      error: e,
    );
    return "A system error occurred. Please try again.";
  }else if(e is FileSystemException){
    log(
      'Error caught: $e',
      name: 'simplifyErrorMessage',
      error: e,
    );
    return "Could not access local storage. Please try again.";
  }else{
    log(
      'Error caught: $e',
      name: 'simplifyErrorMessage',
      error: e,
    );
    return defaultMessage;
  }
}

