class ManageIQ::Providers::IbmCloud::Provider < ::Provider
  has_many :power_virtual_servers_cloud_managers,
           :foreign_key => "provider_id",
           :class => "ManageIQ::Providers::IbmCloud::PowerVirtualServers::CloudManager"
end
