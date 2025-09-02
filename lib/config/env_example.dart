/// Example environment configuration file
/// Copy this file to 'env.dart' and add your real API keys
/// 
/// IMPORTANT: Add 'lib/config/env.dart' to your .gitignore file!

class Environment {
  // Google Cloud Text-to-Speech API Key
  static const String googleTtsApiKey = 'your_google_api_key_here';
  
  // Microsoft Azure Speech Services
  static const String azureSpeechKey = 'your_azure_subscription_key_here';
  static const String azureRegion = 'eastus';
  
  // Amazon Polly
  static const String awsAccessKeyId = 'your_aws_access_key_id_here';
  static const String awsSecretAccessKey = 'your_aws_secret_access_key_here';
  static const String awsRegion = 'us-east-1';
}
