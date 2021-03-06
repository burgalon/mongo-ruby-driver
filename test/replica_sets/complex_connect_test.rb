$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require './test/replica_sets/rs_test_helper'

class ComplexConnectTest < Test::Unit::TestCase
  include ReplicaSetTest

  def teardown
    self.rs.restart_killed_nodes
    @conn.close if defined?(@conn) && @conn
  end

  def test_complex_connect
    primary = Connection.new(self.rs.host, self.rs.ports[0])

    @conn = ReplSetConnection.new([self.rs.host, self.rs.ports[2]], [self.rs.host, self.rs.ports[1]],
      [self.rs.host, self.rs.ports[0]])

    @conn['test']['foo'].insert({:a => 1})
    assert @conn['test']['foo'].find_one

    config = primary['local']['system.replset'].find_one
    config['version'] += 1
    config['members'].delete_if do |member|
      member['host'].include?(self.rs.ports[2].to_s)
    end

    assert_raise ConnectionFailure do
      primary['admin'].command({:replSetReconfig => config})
    end
    self.rs.ensure_up
    assert_raise ConnectionFailure do
      primary['admin'].command({:replSetStepDown => 1})
    end

    rescue_connection_failure do
      assert @conn['test']['foo'].find_one
    end
  end
end
