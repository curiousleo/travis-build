require 'uri'
require 'addressable/uri'
require 'digest/sha1'
require 'openssl'
require 'base64'
require 'time'

module Travis
  module Build
    class Script
      module DirectoryCache
        class Signatures
          class AWS2Signature
            CONTENT_TYPE = 'application/x-gzip'

            attr_reader :verb, :key_pair, :location, :expires

            def initialize(key_pair, verb, location, expires, timestamp=Time.now)
              @key_pair = key_pair
              @verb = verb
              @location = location
              @expires = expires
              @timestamp = timestamp
            end

            def to_uri
              Addressable::URI.new(
                scheme: location.scheme,
                host: location.hostname,
                path: location.path,
              )
            end

            def sign
              hmac = OpenSSL::HMAC.new(@key_pair.secret, OpenSSL::Digest::SHA1.new)
              Base64.strict_encode64(
                hmac.update(
                  message(@verb, @date, @location.bucket, @location.path)
                ).digest
              )
            end

            private

            def timestamp
              # to correspond with the time format shown in
              # http://docs.aws.amazon.com/AmazonS3/latest/dev/RESTAuthentication.html#RESTAuthenticationExamples
              @timestamp.utc.strftime('%a, %e %b %Y %H:%M:%S %z')
            end

            def canonical_headers(verb, date)
              [
                verb.upcase,
                '',
                CONTENT_TYPE,
                timestamp
              ].join("\n")
            end

            def canonical_extension_headers(headers)
              # we will assume headers is a Hash,
              # which means each header is unique, and
              # we skip consolidating headers and their values intø a comma-separated list

              ret = {}
              str = []

              headers.each do |k,v|
                ret.merge!({k.downcase => v})
              end

              ret.sort.each do |k,v|
                str << "#{k}:#{v.gsub(/\r?\n/, ' ')}"
              end

              str.join("\n")
            end

            def message verb, date, bucket, path, ext_headers = {}
              "#{[
                canonical_headers(verb, date),
                canonical_extension_headers(ext_headers)
              ].delete_if { |el| el.empty? }.join("\n")}" <<
              "\n/#{bucket}#{path}"
            end

            def request_headers
              [
                "Content-Type: #{CONTENT_TYPE}",
                "Date: #{timestamp}",
                "Authorization: AWS #{key_pair.id}:#{sign}"
              ]
            end

            def query_params

            end

          end
        end
      end
    end
  end
end