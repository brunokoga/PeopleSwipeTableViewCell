Pod::Spec.new do |s|
  s.name     = 'PeopleSwipeTableViewCell'
  s.version  = '1.0'
  s.authors   = { 'Ali Karagoz' => 'mail@alikaragoz.net', 'Bruno Koga' => 'koga@brunokoga.com' }
  s.homepage = 'https://github.com/brunokoga/PeopleSwipeTableViewCell'
  s.summary  = 'Mailbox app style UITableViewCell.'
  s.license  = 'MIT'
  s.source   = { :git => 'https://github.com/brunokoga/PeopleSwipeTableViewCell.git' }
  s.source_files = 'MCSwipeTableViewCell'
  s.platform = :ios
  s.ios.deployment_target = '5.0'
  s.requires_arc = true
end
