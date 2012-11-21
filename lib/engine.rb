# Copyright (c) 2011, 2012 The University of Manchester, UK.
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
require 'sinatra/base'
require 'sinatra/activerecord'
require 'erb'
require 'rexml/document'
require 'rexml/text'
require_relative 'models'
require_relative 'helpers'

module Wrangler
  class Engine < Sinatra::Base

    register Sinatra::ActiveRecordExtension

    helpers Wrangler::Helpers

    def initialize(server = nil, credentials = nil)
      super()

      @server = server ||= Wrangler.taverna
      @creds = credentials ||= Wrangler.credentials
    end

    configure do
      set :root, BASE_DIR
      set :database, "sqlite3:///#{BASE_DIR}/#{ENV['RACK_ENV']}.db"
    end

    #
    # Routes, &c.
    #

    # everything returned by this API is xml and utf-8
    before do
      headers "Content-Type"=>"application/xml;charset=utf-8"
    end

    # not found!
    not_found do
      headers "Content-Type"=>"application/xml;charset=utf-8"
      erb(:e404, :locals => { :request => request })
    end

    #
    # Root
    #

    get '/?' do
      erb(:index, :locals => { :root => request.url.chomp('/') })
    end

    #
    # Runs
    #

    # GET all runs (truncated details).
    get '/runs/?' do
      stored_runs = Run.all

      runs = {}
      @server.runs(@creds).each do |run|
        runs[run.id] = run
      end

      # update run info?
      stored_runs.each do |run|
        next if run.finished?
        next unless run.on_server?
        update_run_state(run, runs[run.instance])
      end

      erb(:runs, :locals => {:runs => stored_runs})
    end

    # CREATE a new run.
    post '/runs/?' do
      # Bail out if we're not given xml.
      halt 415 unless request.media_type == "application/xml"

      # Read the request body.
      request.body.rewind
      begin
        doc = REXML::Document.new(request.body.read)
        r_flow = REXML::XPath.first(doc, "//workflow").text
        r_name = REXML::XPath.first(doc, "//name").text
        r_desc = REXML::XPath.first(doc, "//description").text
        r_user = REXML::XPath.first(doc, "//author").text
      rescue
        halt 415
      end

      # Create the run.
      begin
        workflow = Workflow.find_by_uuid(r_flow)
      rescue
        halt 404
      end
      wf_file = File.read(File.join(Wrangler::WORKFLOW_DIR, workflow.filename))
      run = @server.create_run(wf_file, @creds)

      # Store it in the db
      r_id = run.id
      r_created = run.create_time
      new_run = Run.create do |r|
        r.instance = r_id
        r.on_server = true
        r.workflow = r_flow
        r.username = r_user
        r.name = r_name
        r.description = r_desc
        r.createtime = r_created
      end

      # Set the inputs, if any
      REXML::XPath.each(doc, "//inputs/input") do |input|
        port = input.elements["id"].text.chomp
        value = input.elements["value"].text.chomp
        new_run.inputs.create do |i|
          i.name = port
          i.value = value
        end

        run.input_port(port).value = value
      end

      # Set the supplied outputs (these are fake outputs really).
      REXML::XPath.each(doc, "//outputs/output") do |output|
        port = output.elements["id"].text.chomp
        value = output.elements["value"].text.chomp
        new_run.outputs.create do |o|
          o.name = port
          o.value = value
        end

        run.input_port(port).value = value
      end

      # Go through each workflow output and set up the run with it, unless it
      # is a fake output
      workflow.outputs_hash.each do |out|
        unless out[1][:fake]
          new_run.outputs.create do |o|
            o.name = out[0]          
          end
        end
      end

      # Start it running
      run.start
      new_run.starttime = run.start_time
      new_run.state = run_status(run)
      new_run.save!

      # Return the link to the new run.
      headers "Location" => "/runs/#{new_run.instance}"
      201
    end

    # DELETE all runs.
    delete '/runs/?' do
      @server.delete_all_runs(@creds)
      Run.destroy_all

      204
    end

    #
    # Run
    #

    # GET the full details of the specified run.
    get '/runs/:run/?' do
      begin
        stored_run = Run.find_by_instance(params[:run])
        workflow = Workflow.find_by_uuid(stored_run.workflow)
      rescue
        pass
      end

      # update run info?
      unless stored_run.finished?
        run = @server.run(stored_run.instance, @creds)
        update_run_state(stored_run, run)
      end

      erb(:run, :locals => {:run => stored_run, :workflow => workflow})
    end

    # DELETE the specified run.
    delete '/runs/:run/?' do
      begin
        stored_run = Run.find_by_instance(params[:run])
      rescue
        pass
      end

      run = @server.run(stored_run.instance, @creds)
      run.delete unless run.nil?
      stored_run.destroy

      204
    end

    #
    # Run outputs
    #

    #
    # Run activities
    #

    get '/runs/:run/activities/?' do
      erb(:activities)
    end

    #
    # Workflows
    #

    # GET all workflows (truncated details).
    get '/workflows/?' do
      erb(:workflows, :locals => {:workflows => Workflow.all})
    end

    # GET a single workflow's full details.
    get '/workflows/:workflow/?' do
      begin
        workflow = Workflow.find_by_uuid(params[:workflow])
      rescue
        pass
      end

      erb(:workflow, :locals => {:workflow => workflow})
    end

    # GET all the runs that were created using the specified workflow template.
    get '/workflows/:workflow/runs/?' do
      p params[:workflow]
      begin
        runs = Run.find_all_by_workflow(params[:workflow])
      rescue
        pass
      end

      erb(:runs, :locals => {:runs => runs})
    end
  end
end
