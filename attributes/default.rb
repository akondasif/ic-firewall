#
# Cookbook Name:: rvm
# Attributes:: default
#
# Author:: Fletcher Nichol <fnichol@nichol.ca>
#
# Copyright 2010, 2011, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

default[:rvm][:root_path] = "/usr/local/rvm"
default[:rvm][:group_users] = []
default[:rvm][:rvmrc] = Hash.new

default[:rvm][:system_installer_url] = "http://bit.ly/rvm-install-system-wide"

default[:rvm][:revision] = "HEAD"

# ruby that will get set to `rvm use default`. Use fully qualified ruby names.
default[:rvm][:default_ruby] = "ruby-1.9.2-p180"

# list of rubies that will be installed
default[:rvm][:rubies] = [ select_ruby(rvm[:default_ruby]) ]

# list of gems to be installed in global gemset of all rubies
default[:rvm][:global_gems] = [
  { :name => "bundler" }
]

# hash of gemsets and their list of gems to be installed.
default[:rvm][:gems] = Hash.new