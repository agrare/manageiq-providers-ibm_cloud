class ManageIQ::Providers::IbmCloud::PowerVirtualServers::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :AuthKeyPair
  require_nested :Refresher
  require_nested :RefreshWorker
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :Template
  require_nested :Vm

  has_one :network_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::IbmCloud::PowerVirtualServers::NetworkManager",
          :autosave    => true,
          :dependent   => :destroy,
          :inverse_of  => :parent_manager

  has_one :storage_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::IbmCloud::PowerVirtualServers::StorageManager",
          :autosave    => true,
          :dependent   => :destroy,
          :inverse_of  => :parent_manager

  before_create :ensure_managers

  belongs_to :provider,
             :class_name => "ManageIQ::Providers::IbmCloud::Provider",
             :inverse_of => :power_virtual_servers_cloud_managers,
             :dependent  => :destroy,
             :autosave   => true

  delegate :name=,
           :zone,
           :zone=,
           :zone_id,
           :zone_id=,
           :authentications,
           :authentications=,
           :authentication_status,
           :authentication_status_ok?,
           :to => :provider

  supports :provisioning

  def image_name
    "ibm"
  end

  def required_credential_fields(_type)
    [:auth_key]
  end

  def supported_auth_attributes
    %w[auth_key]
  end

  def self.hostname_required?
    # TODO: ExtManagementSystem is validating this
    false
  end

  def self.ems_type
    @ems_type ||= "ibm_cloud_power_virtual_servers".freeze
  end

  def self.description
    @description ||= "IBM Power Systems Virtual Servers".freeze
  end

  def self.params_for_create
    ManageIQ::Providers::IbmCloud::Provider.params_for_create.dup.tap do |params|
      params[:fields] << {
        :component  => "text-field",
        :name       => "uid_ems",
        :id         => "uid_ems",
        :label      => _("PowerVS Service GUID"),
        :isRequired => true,
        :validate   => [{:type => "required"}],
      }
    end
  end

  # Verify Credentials
  # args:
  # {
  #   "uid_ems"         => "",
  #   "authentications" => {
  #     "default" => {
  #       "auth_key" => "",
  #     }
  #   }
  # }
  def self.verify_credentials(args)
    pcloud_guid = args["uid_ems"]
    auth_key = args.dig("authentications", "default", "auth_key")
    auth_key = MiqPassword.try_decrypt(auth_key)
    auth_key ||= find(args["id"]).authentication_token('default')

    !!raw_connect_power_iaas(auth_key, pcloud_guid)
  end

  def self.raw_connect_power_iaas(api_key, pcloud_guid)
    raise MiqException::MiqInvalidCredentialsError, _("Missing credentials") if pcloud_guid.blank?

    token              = ManageIQ::Providers::IbmCloud::Provider.raw_connect(api_key)
    power_iaas_service = IBM::Cloud::SDK::ResourceController.new(token).get_resource(pcloud_guid)

    IBM::Cloud::SDK::PowerIaas.new(power_iaas_service.region_id, pcloud_guid, token, power_iaas_service.crn, power_iaas_service.account_id)
  end

  def self.create_from_params(params, endpoints, authentications)
    new(params).tap do |ems|
      endpoints.each { |endpoint| ems.assign_nested_endpoint(endpoint) }
      authentications.each { |authentication| ems.assign_nested_authentication(authentication) }

      ems.provider.save!
      ems.save!
    end
  end

  def edit_with_params(params, endpoints, authentications)
    tap do |ems|
      transaction do
        # Remove endpoints/attributes that are not arriving in the arguments above
        ems.endpoints.where.not(:role => nil).where.not(:role => endpoints.map { |ep| ep['role'] }).delete_all
        ems.authentications.where.not(:authtype => nil).where.not(:authtype => authentications.map { |au| au['authtype'] }).delete_all

        ems.assign_attributes(params)
        ems.endpoints = endpoints.map(&method(:assign_nested_endpoint))
        ems.authentications = authentications.map(&method(:assign_nested_authentication))

        ems.provider.save!
        ems.save!
      end
    end
  end

  def connect(options = {})
    service = options[:service]&.underscore || "power_iaas"
    meth    = "raw_connect_#{service}"

    raise ArgumentError, "Invalid service #{service}" unless respond_to?(meth)

    send(meth, authentication_key(options[:auth_type]), uid_ems)
  end

  delegate :raw_connect_power_iaas, :to => :class

  def verify_credentials(_auth_type = nil, options = {})
    connect(options)
    true
  end

  def ensure_managers
    build_network_manager unless network_manager
    build_storage_manager unless storage_manager
  end

  def provider
    super || build_provider
  end

  def name
    "#{provider.name} Power Virtual Servers"
  end
end
