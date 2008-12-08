require 'resolv'

######################################################################
### core_ext
unless Module.respond_to?(:mattr_accessor)
  require File.dirname(__FILE__) + '/../core_ext/module/attribute_accessors'
end

unless [].respond_to?(:extract_options!)
  require File.dirname(__FILE__) + '/../core_ext/array/extract_options'      
  class Array #:nodoc:
    include ActiveSupport::CoreExtensions::Array::ExtractOptions
  end
end



######################################################################
### HostsAccess

module HostsAccess
  mattr_accessor :allow
  mattr_accessor :allow_controller

  private
    def hosts_access
      if HostsAccess.allow.blank?
        return hosts_access_allowed("not restricted (no rules)")
      end

      if allow_controller
        Array(HostsAccess.allow_controller).each do |name|
          return hosts_access_allowed("#{controller_name} controller is not restricted") if name == controller_name
        end
      end

      Array(HostsAccess.allow).each do |host|
        address = host
        address = Resolv.getaddress(host) rescue host unless /\A[\d\.]+\Z/ === host
        return hosts_access_allowed("#{host} is allowed") if request.remote_ip == address
      end

      return hosts_access_denied("#{request.remote_ip} is denied")
    end

    def hosts_access_allowed(reason)
      logger.info "[HostsAccess] OK: #{reason}"
      return true
    end

    def hosts_access_denied(reason)
      logger.info "[HostsAccess] NG: #{reason}"
      return false
    end
end


######################################################################
### for Merb
if defined?(Merb::Plugins)
  module HostsAccess
    def logger
      Merb.logger
    end
  end

  Merb::BootLoader.after_app_loads do
    Application.class_eval do
      include HostsAccess
      before :hosts_access

      private
        def hosts_access_denied(reason)
          super
          throw :halt
        end
    end
  end
end

######################################################################
### for Rails

if defined?(ActionController::Base)
  ActionController::Base.class_eval do
    include HostsAccess
    before_filter :hosts_access
  end
end
