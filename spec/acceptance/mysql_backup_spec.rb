require 'spec_helper_acceptance'
require_relative './mysql_helper.rb'

describe 'mysql::server::backup class' do
  context 'should work with no errors' do
    pp = <<-MANIFEST
        class { 'mysql::server': root_password => 'password' }
        mysql::db { [
          'backup1',
          'backup2'
        ]:
          user     => 'backup',
          password => 'secret',
        }

        class { 'mysql::server::backup':
          backupuser     => 'myuser',
          backuppassword => 'mypassword',
          backupdir      => '/tmp/backups',
          backupcompress => true,
          postscript     => [
            'rm -rf /var/tmp/mysqlbackups',
            'rm -f /var/tmp/mysqlbackups.done',
            'cp -r /tmp/backups /var/tmp/mysqlbackups',
            'touch /var/tmp/mysqlbackups.done',
          ],
          execpath      => '/usr/bin:/usr/sbin:/bin:/sbin:/opt/zimbra/bin',
        }
    MANIFEST
    it 'when configuring mysql backups' do
      apply_manifest_and_idempotent(pp)
    end
  end

  describe 'mysqlbackup.sh' do
    before(:all) do
      pre_run
    end

    it 'runs mysqlbackup.sh with no errors' do
      unless mysql_version_is_greater_than('5.7.0')
        run_shell('/usr/local/sbin/mysqlbackup.sh') do |r|
          expect(r.stderr).to eq('')
        end
      end
    end

    it 'dumps all databases to single file' do
      unless mysql_version_is_greater_than('5.7.0')
        run_shell('ls -l /tmp/backups/mysql_backup_*-*.sql.bz2 | wc -l') do |r|
          expect(r.stdout).to match(%r{1})
          expect(r.exit_code).to be_zero
        end
      end
    end

    context 'should create one file per database per run' do
      it 'executes mysqlbackup.sh a second time' do
        unless mysql_version_is_greater_than('5.7.0')
          run_shell('sleep 1')
          run_shell('/usr/local/sbin/mysqlbackup.sh')
        end
      end

      it 'creates at least one backup tarball' do
        unless mysql_version_is_greater_than('5.7.0')
          run_shell('ls -l /tmp/backups/mysql_backup_*-*.sql.bz2 | wc -l') do |r|
            expect(r.stdout).to match(%r{2})
            expect(r.exit_code).to be_zero
          end
        end
      end
    end
    # rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength
  end

  context 'with one file per database' do
    context 'should work with no errors' do
      pp = <<-MANIFEST
          class { 'mysql::server': root_password => 'password' }
          mysql::db { [
            'backup1',
            'backup2'
          ]:
            user     => 'backup',
            password => 'secret',
          }

          class { 'mysql::server::backup':
            backupuser        => 'myuser',
            backuppassword    => 'mypassword',
            backupdir         => '/tmp/backups',
            backupcompress    => true,
            file_per_database => true,
            postscript        => [
              'rm -rf /var/tmp/mysqlbackups',
              'rm -f /var/tmp/mysqlbackups.done',
              'cp -r /tmp/backups /var/tmp/mysqlbackups',
              'touch /var/tmp/mysqlbackups.done',
            ],
            execpath          => '/usr/bin:/usr/sbin:/bin:/sbin:/opt/zimbra/bin',
          }
      MANIFEST
      it 'when configuring mysql backups' do
        apply_manifest_and_idempotent(pp)
      end
    end

    describe 'mysqlbackup.sh' do
      before(:all) do
        pre_run
      end

      it 'runs mysqlbackup.sh with no errors without root credentials' do
        unless mysql_version_is_greater_than('5.7.0')
          run_shell('HOME=/tmp/dontreadrootcredentials /usr/local/sbin/mysqlbackup.sh') do |r|
            expect(r.stderr).to eq('')
          end
        end
      end

      it 'creates one file per database' do
        unless mysql_version_is_greater_than('5.7.0')
          ['backup1', 'backup2'].each do |database|
            run_shell("ls -l /tmp/backups/mysql_backup_#{database}_*-*.sql.bz2 | wc -l") do |r|
              expect(r.stdout).to match(%r{1})
              expect(r.exit_code).to be_zero
            end
          end
        end
      end

      it 'executes mysqlbackup.sh a second time' do
        unless mysql_version_is_greater_than('5.7.0')
          run_shell('sleep 1')
          run_shell('HOME=/tmp/dontreadrootcredentials /usr/local/sbin/mysqlbackup.sh')
        end
      end

      it 'has one file per database per run' do
        unless mysql_version_is_greater_than('5.7.0')
          ['backup1', 'backup2'].each do |database|
            run_shell("ls -l /tmp/backups/mysql_backup_#{database}_*-*.sql.bz2 | wc -l") do |r|
              expect(r.stdout).to match(%r{2})
              expect(r.exit_code).to be_zero
            end
          end
        end
      end
      # rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength
    end
  end
end
