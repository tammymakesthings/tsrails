#
Dir[File.join(::Rails.root.to_s, 'lib', 'extensions', '*.rb')].each do |f|
  require f
end

Dir[File.join(::Rails.root.to_s, 'lib', '*.rb')].each do |f|
  require f
end  
