# Copyright (c) 2012 The University of Manchester, UK.
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
#  * Neither the names of The University of Manchester nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# Author: Robert Haines

require 'rubygems'
require 'bundler/setup'
require 't2-server'
require 'net/http'

module Wrangler
  class Orchestrator

    INSTANCE_TAG = "Taverna Worker (%s)"

    def initialize(run_status, workflow, cloud)
      @run_status = run_status
      @workflow = workflow
      @worker = @workflow.worker
      @cloud = cloud
      @creds = T2Server::HttpBasic.new(@worker.taverna_user, @worker.taverna_pass)
    end

    def perform
      # Set up instance to run the workflow on.
      instance = setup_instance

      # Run the workflow.
      uri = full_taverna_uri(instance)
      wkf = File.read(File.join(Wrangler::WORKFLOW_DIR, @workflow.filename))
      puts "Connecting to Taverna Server at #{uri}..."
      T2Server::Server.new(uri) do |server|
        puts "Creating run..."
        server.create_run(wkf, @creds) do |run|
          puts "Setting input ports..."
          set_input_ports(run)

          # Start the run.
          puts "Starting run and waiting for it to finish..."
          run.start
          @run_status.state = "RUNNING"
          @run_status.starttime = run.start_time
          @run_status.save!
          run.wait(10)

          # Run is finished.
          @run_status.state = "DONE"
          @run_status.finishtime = run.finish_time
          @run_status.outputs.each do |output|
            if output.value.nil?
              output.value = run.output_port(output.name).value
              output.save!
            end
          end
          @run_status.save!

          # Delete the run from the server.
          run.delete
          puts "Run deleted..."
        end

        # Are there any more workflows running on this instance?
        if server.runs(@creds).count == 0
          puts "This instance is now empty, but there might be a run in the queue..."
          sleep 20
          if server.runs(@creds).count == 0
            @cloud.terminate_instance(instance)
            puts "This instance is still empty, so terminate it..."
          end
        end
      end

      puts "Done."
    end

  private

    def full_taverna_uri(instance)
      port = @worker.taverna_port
      path = @worker.taverna_path
      scheme = port == 8080 ? "http://" : "https://"
      URI.parse("#{scheme}#{instance.dns_name}:#{port}/#{path}")
    end

    def set_input_ports(run)
      # Set real inputs.
      @run_status.inputs.each do |input|
        run.input_port(input.name).value = input.value
      end

      # Set any fake outputs.
      @run_status.outputs.each do |output|
        run.input_port(output.name).value = output.value unless output.value.nil?
      end
    end

    def is_taverna_up?(instance)
      http = Net::HTTP.new(instance.dns_name, @worker.taverna_port)
      http.open_timeout = 2
      http.read_timeout = 2
      begin
        http.get("/#{@worker.taverna_path}").is_a? Net::HTTPSuccess
      rescue Timeout::Error, SystemCallError
        sleep 10
        puts "Still waiting for Taverna..."
        retry
      end
    end

    def setup_instance
      # Are there any suitable running instances we can reuse?
      puts "Getting running instances..."
      running = @cloud.running_instances(@worker.image_id)

      instance = unless running.empty?
        # There is at least one suitable instance, but are any free?
        puts "Got (at least) one!"
        check_running_instances(running)
      end
      return instance unless instance.nil?

      # Are there any suitable pending instances we can wait for?
      puts "Getting pending instances..."
      pending = @cloud.pending_instances(@worker.image_id).count
      unless pending == 0
        puts "Waiting for pending instance to come up..."
        loop do
          sleep 10
          break if pending > @cloud.pending_instances(@worker.image_id).count
        end

        # There was a pending instance, now it is running. Give it time though.
        sleep 10
        return setup_instance
      end

      # There are no suitable instances running or they're busy. Start one.
      puts "Nothing suitable, let's start a new instance..."
      instance = @cloud.start_instance(@worker.image_id, @worker.instance_size,
        @worker.taverna_port, format(INSTANCE_TAG, @worker.name))

      # Check taverna comes up too.
      puts "Now wait for Taverna to appear..."
      sleep 10
      unless is_taverna_up? instance
        @run_status.status = "FAILED"
        @run_status.save!
        exit 0
      end

      instance
    end

    def check_running_instances(instances)
      instances.each do |i|
        next unless is_taverna_up? i

        uri = full_taverna_uri(i)
        server = T2Server::Server.new(uri)
        tenants = 0
        print "This one (#{uri}) has...  "
        server.runs(@creds).each do |run|
          if run.running? || run.initialized?
          tenants += 1
          break if tenants >= @worker.tenancy_limit
          end
        end
        puts "#{tenants} tenant(s)...  "
        next if tenants >= @worker.tenancy_limit

        # Return this instance if it has space
        puts "Not busy. Use it."
        return i
      end

      puts "No suitable running instances."
      nil
    end

  end
end
