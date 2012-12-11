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
require 'bundler/setup'
require 'yaml'
require 'logger'

module Wrangler

  ENVIRONMENT = ENV['RACK_ENV'] || "development"
  BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__), ".."))
  CONFIG_DIR = File.join(BASE_DIR, "config")
  LOG_DIR = File.join(BASE_DIR, "log")
  DATABASE_FILE = File.join(CONFIG_DIR, "database.yml")
  WORKFLOW_DIR = File.join(BASE_DIR, "workflows")

  LOGGER = Logger.new(File.join(LOG_DIR, "wrangler.log"))

  DATABASE = begin
    YAML.load(File.open(DATABASE_FILE, "r"))
  rescue ArgumentError => e
    puts "Could not parse database configuration file: #{e.message}"
    exit(1)
  end
end

require_relative 'job'
require_relative 'engine'
