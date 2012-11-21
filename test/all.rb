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

# This must go BEFORE you require the app under test!
ENV['RACK_ENV'] = "test"

require_relative '../lib/wrangler'
require 'test/unit'
require 'rack/test'

class WranglerTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Wrangler::Engine.new
  end

  def test_index
    get '/' do |r|
      assert r.ok?
      assert_equal "application/xml;charset=utf-8", r.content_type
      assert_not_equal 0, r.content_length
    end
  end

  def test_workflows
    get '/workflows' do |r|
      assert r.ok?
      assert_equal "application/xml;charset=utf-8", r.content_type
      assert_not_equal 0, r.content_length
    end
  end

  def test_runs
    get '/runs' do |r|
      assert r.ok?
      assert_equal "application/xml;charset=utf-8", r.content_type
      assert_not_equal 0, r.content_length
    end
  end
end
