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
require 'aws'

module Wrangler
  class AWS

    def initialize(config)
      @config = config
      @ec2 = nil
      @zone = nil
      @firewall = nil
    end

    def running_instances(ami_id)
      instances_by_state(ami_id, :running)
    end

    def pending_instances(ami_id)
      instances_by_state(ami_id, :pending)
    end

    def start_instance(ami_id, size, port, tag = nil)
      puts "Starting instance..."
      params = {:image_id => ami_id, :instance_type => size,
        :security_groups => security_group(port),
        :availability_zone => availability_zone }
      instance = connection.instances.create(params)
      sleep 10
      tag_instance(instance, "Name", tag) unless tag.nil?

      puts "Waiting for instance to come up..."
      sleep 10 while instance.status == :pending

      puts "It's running now..."
      instance
    end

    def tag_instance(instance, key, value)
      instance.add_tag(key, :value => value)
    end

    def terminate_instance(instance)
      instance.delete
    end

  private

    def connection
      return @ec2 unless @ec2.nil?

      puts "Connect to EC2 - this should only happen once!"
      ec2 = ::AWS::EC2.new(@config['credentials'])
      region = ec2.regions[@config['location']['region']]

      # A region acts like an ec2
      @ec2 = region.exists? ? region : ec2
    end

    def availability_zone
      return @zone unless @zone.nil?

      zone = @config['location']['zone']
      zones = @ec2.availability_zones
      if zones.map(&:name).include? zone
        @zone = zones[zone]
      else
        @zone = :none
      end
    end

    def security_group(port)
      return @firewall unless @firewall.nil?

      connection.security_groups.filter("group-name", @config['firewall']).first
    end

    def instances_by_state(ami_id, state = :running)
      ::AWS.memoize do
        connection.instances.inject([]) do |ins, i|
          ins << i if i.image_id == ami_id && i.status == state
          ins
        end
      end
    end

  end
end
