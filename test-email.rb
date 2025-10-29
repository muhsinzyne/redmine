#!/usr/bin/env ruby
# Test email configuration for Redmine

puts "=" * 50
puts "Redmine Email Configuration Test"
puts "=" * 50
puts ""

# Check if we're in the right directory
unless File.exist?('config.ru')
  puts "❌ Error: This script must be run from the Redmine root directory"
  exit 1
end

# Load Rails environment
require File.expand_path('config/environment', __dir__)

puts "✓ Rails environment loaded"
puts "✓ Environment: #{Rails.env}"
puts ""

# Check SMTP configuration
smtp_settings = ActionMailer::Base.smtp_settings
puts "SMTP Configuration:"
puts "  Server: #{smtp_settings[:address]}:#{smtp_settings[:port]}"
puts "  Username: #{smtp_settings[:user_name]}"
puts "  SSL: #{smtp_settings[:ssl]}"
puts "  Auth: #{smtp_settings[:authentication]}"
puts ""

# Get test email
print "Enter your email address to send test email: "
test_email = gets.chomp

if test_email.empty?
  puts "❌ No email provided. Exiting."
  exit 1
end

puts ""
puts "Sending test email to: #{test_email}"
puts "From: #{smtp_settings[:user_name]}"
puts ""

begin
  # Send test email
  mail = ActionMailer::Base.mail(
    from: smtp_settings[:user_name],
    to: test_email,
    subject: "✅ Redmine Email Test - #{Time.now.strftime('%Y-%m-%d %H:%M')}",
    body: <<~BODY
      This is a test email from your Redmine installation.
      
      If you received this email, your SMTP configuration is working correctly!
      
      Configuration Details:
      - Environment: #{Rails.env}
      - SMTP Server: #{smtp_settings[:address]}:#{smtp_settings[:port]}
      - Sender: #{smtp_settings[:user_name]}
      - Sent at: #{Time.now}
      
      Your Redmine is ready to send notifications! 🎉
    BODY
  )
  
  mail.deliver_now
  
  puts "=" * 50
  puts "✅ Email sent successfully!"
  puts "=" * 50
  puts ""
  puts "Check your inbox at: #{test_email}"
  puts "It may take a few seconds to arrive."
  puts ""
  puts "If you don't see it:"
  puts "  1. Check your spam folder"
  puts "  2. Verify the email address is correct"
  puts "  3. Check log/development.log for errors"
  puts ""
  
rescue => e
  puts "=" * 50
  puts "❌ Error sending email!"
  puts "=" * 50
  puts ""
  puts "Error: #{e.class}"
  puts "Message: #{e.message}"
  puts ""
  puts "Troubleshooting:"
  puts "  1. Check config/configuration.yml for correct SMTP settings"
  puts "  2. Verify Gmail App Password is valid"
  puts "  3. Ensure 2-Step Verification is enabled in Google Account"
  puts "  4. Check firewall allows outbound port 465"
  puts "  5. See EMAIL_SETUP.md for more help"
  puts ""
  puts "Full error:"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

