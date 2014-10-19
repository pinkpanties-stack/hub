require 'json'
require 'sinatra/base'
          type.split(/\s*[;,]\s*/, 2).first.downcase =~ /[\/+]json$/
      end
    end

    class App < Sinatra::Base
      def invoke
        res = super
        content_type :json unless response.content_type
        response.body = '{}' if blank_response?(response.body) ||
          (response.body.respond_to?(:[]) && blank_response?(response.body[0]))
        res
      end

      def blank_response?(obj)
        obj.nil? || (obj.respond_to?(:empty?) && obj.empty?)
      klass = Class.new(App)
      klass.error(404, 401) { content_type :json; nil }

        def assert_basic_auth(*expected)
          require 'rack/auth/basic'
          auth = Rack::Auth::Basic::Request.new(env)
          if auth.credentials != expected
            halt 401, json(
              :message => "expected %p; got %p" % [
                expected, auth.credentials
              ]
            )
          end
        end

        def generate_patch(subject)
        <<PATCH
From 7eb75a26ee8e402aad79fcf36a4c1461e3ec2592 Mon Sep 17 00:00:00 2001
From: Mislav <mislav.marohnic@gmail.com>
Date: Tue, 24 Jun 2014 11:07:05 -0700
Subject: [PATCH] #{subject}
---
diff --git a/README.md b/README.md
new file mode 100644
index 0000000..ce01362
--- /dev/null
+++ b/README.md
+hello
-- 
1.9.3
PATCH
        end