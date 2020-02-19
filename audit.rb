require 'json'
require 'date'
filename = ARGV[0]
puts "Verifying s3 Cloudtrail log :=> #{filename}"
begin
	file = File.read(filename)

	events = JSON.parse(file)

	broker = []
	non_broker = []
	events.each do |event|
		if ["cg-s3-broker", "cg-federalist-s3-broker"].include?(event["username"])
			next if ["PutBucketEncryption", "PutBucketPolicy", "CreateBucket", "PutBucketTagging", "DeleteBucket"].include?(event["event_name"])
			broker << event
		else
			if event["event_name"] == "PutBucketWebsite"
				next if events.select{|e| (e["bucket_name"] == event["bucket_name"]) && e["event_name"] == "CreateBucket" && (Date.parse(event["event_time"]) == Date.parse(e["event_time"]))}.first
			end
			non_broker << event
		end
	end

	report = {}
	report["log"] = events
	report["unexpected"] = (broker + non_broker).flatten
	directory = "./out/"
	Dir.mkdir(directory) unless Dir.exist?(directory)
	open(directory + File.basename(filename, ".*") + "_" + DateTime.now.strftime("%y%m%d%H%M%S") + File.extname(filename), 'w+') { |f|
	  f.puts report.to_json
	}
	if broker.empty? && non_broker.empty?		
		puts "Success"
	else
		puts "Events requiring futher investigation:"
		if broker.any?
			puts "\n\nBrokered Events: #{broker.count}"
			puts broker
		end
		if non_broker.any?
			puts "\n\nNon-Brokered Events #{non_broker.count}"
			puts non_broker
		end
	end
	
rescue => ex
	puts ex
	puts ex.backtrace
end
