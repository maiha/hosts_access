require 'resolv'

module HostsAccess
  def self.included(base)
    base.class_eval do
      include InstanceMethods
      before_filter :hosts_access
    end
  end

  mattr_accessor :allow
  mattr_accessor :allow_controller

  module InstanceMethods
  private
    def hosts_access
      if allow.blank?
        logger.info "[HostsAccess] OK: not restricted (no rules)"
        return true
      end

      if allow_controller
        Array(allow_controller).each do |name|
          if name == controller_name
            logger.info "[HostsAccess] OK: #{controller_name} controller is not restricted"
            return true
          end
        end
      end

      Array(allow).each do |host|
        address = host
        address = Resolv.getaddress(host) rescue host unless /\A[\d\.]+\Z/ === host
        if request.remote_ip == address
          logger.info "[HostsAccess] OK: #{host} is allowed"
          return true
        end
      end

      logger.info "[HostsAccess] NG: #{request.remote_ip} is denied"
      return false
    end
  end
end
