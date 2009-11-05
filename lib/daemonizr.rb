require 'rubygems'
require 'daemons'
require 'logger'

class Daemonizr
  CLUSTERS  = {}

  def initialize(instance_name, options = {})
    @name = instance_name
    @pid_path = options[:pid_path]
    @log_to_stdout = true
    
    if options[:log_file].is_a?(String)
      raise ArgumentError.new("Invalid log_level value.") unless [:debug, :info, :warn, :error, :fatal, nil].include?(options[:log_level])
      @logger = Logger.new(options[:log_file]) 
      @logger.level = eval("Logger::#{(options[:log_level] || :info).to_s.upcase}")
    end
  end
  
  def start_cluster(name, count, prok)
    log :info, "Starting new cluster named '#{name}' with #{count} processes..."
    raise "Can't start another cluster with the name #{name}. Already running." if cluster_exists?(name)
    CLUSTERS[name] = { :count => count, :proc => prok, :processes => {} }
    (1..count).each do |id|
      log :debug, "Asking to start process #{id}/#{count} for cluster '#{name}'..."
      start_daemon(name, id)
    end
    true
  end

  def stop_all_clusters
    log :debug, "Stopping all clusters..."
    CLUSTERS.each_key do |k|
      stop_cluster(k)
    end
  end

  def monitor_cluster!(interval = 5)
    log :info, "Monitoring of clusters starting..."
    while "ruby" > "java" do
      CLUSTERS.each_key do |cluster_name|
        CLUSTERS[cluster_name][:processes].each_key do |process_id|
          unless CLUSTERS[cluster_name][:processes][process_id].running?
            log :warn, "Process ##{process_id} of cluster '#{cluster_name}' is not running. Restarting..."
            start_daemon(cluster_name, process_id)
          end
        end
      end
      
      begin
        sleep interval
      rescue Interrupt
        # Process was killed. Stop clusters.
        puts "\n"
        log :info, "Received SIGTERM. Stopping all clusters and stop monitoring."
        stop_all_clusters
        log :info, "Monitoring stopped."
        return true
      end
    end
  end
  

  protected
  def start_daemon(name, id)
    if CLUSTERS[name][:processes][id] && CLUSTERS[name][:processes][id].running?
      log :error, "Process ##{id} for cluster '#{name}' is already running. Can't start it again."
      raise ClusterAlreadyRunningException
    else
      # remove_stale_pid_file(name, id)
      process_title = "#{@name}: #{name} #{id}/#{CLUSTERS[name][:count]}"
      log :info, "Starting process '#{process_title}'..."
      prok = CLUSTERS[name][:proc]
      
      CLUSTERS[name][:processes][id] = Daemons.call(:multiple=>true) do
        # TODO: figure out why it gets truncated
        $PROGRAM_NAME = process_title
        # write_pid_file(name, id)
        prok.call
      end
      
      log :info, "Process '#{process_title}' started with PID #{CLUSTERS[name][:processes][id].pid.pid}."
      return CLUSTERS[name][:processes][id]
    end
  end

  def stop_cluster(name)
    log :info, "Stopping cluster '#{name}'..."
    raise ClusterDoesNotExistException unless cluster_exists?(name)
    
    CLUSTERS[name][:processes].each_key do |k|
      log :debug, "Stopping process ##{k} of cluster '#{name}'..."
      CLUSTERS[name][:processes][k].stop
      # remove_stale_pid_file(name, k)
    end
    
    CLUSTERS.delete(name); true
  end

  def cluster_exists?(name)
    return CLUSTERS.keys.include?(name)
  end
  
  def log(severity, msg)
    msg = format_log_message(msg)
    @logger.send(severity, msg) if @logger
    puts msg if @log_to_stdout || !@logger
  end
  
  def format_log_message(msg)
    msg
  end
  
  # def pid_file(cluster, id)
  #   if @pid_path
  #     f = @pid_path.strip
  #     f += File::SEPARATOR unless f[-1,1] == File::SEPARATOR
  #     f += "#{@name}-#{cluster}-#{id}.pid"
  #   else
  #     nil
  #   end
  # end
  # 
  # def write_pid_file(name, id)
  #   pf = pid_file(name, id)
  #   if pf
  #     log :debug, "Writing PID to #{pf}"
  #     FileUtils.mkdir_p File.dirname(pf)
  #     open(pf,"w") { |f| f.write(Process.pid) }
  #     File.chmod(0644, pf)
  #   end
  # end
  # 
  # def remove_stale_pid_file(name, id)
  #   pf = pid_file(name, id)
  #   if File.exist?(pf)
  #     pid = File.open(pf).read
  #     File.delete(pf) unless pid && process_running?(pid)
  #   end
  # end
  # 
  # def process_running?(pid)
  #   begin
  #     Process.kill(0, pid.to_i)
  #     true
  #   rescue Errno::ESRCH
  #     false
  #   end
  # end
  
  class ClusterAlreadyRunningException < Exception; end
  class ClusterDoesNotExistException < Exception; end
end



# d = Daemonizr.new("Daemonizr", :pid_path => "/tmp/")
# d.start_cluster("MyServer", 3, lambda {loop{ sleep 2; File.open("/tmp/daemonizr.log", "a") { |f| f.puts "#{Process.pid}: #{Time.now}" }  }})
# d.monitor_cluster! # Will hang here until the process is terminated with SIGTERM (kill 5).
