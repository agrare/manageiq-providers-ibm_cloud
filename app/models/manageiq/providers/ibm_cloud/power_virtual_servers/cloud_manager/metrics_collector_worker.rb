class ManageIQ::Providers::IbmCloud::PowerVirtualServers::CloudManager::MetricsCollectorWorker < ManageIQ::Providers::BaseManager::MetricsCollectorWorker
  self.default_queue_name = "ibm_cloud_power_virtual_servers"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for IBM PowerVS"
  end
end
