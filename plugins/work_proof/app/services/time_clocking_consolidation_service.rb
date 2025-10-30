class TimeClockingConsolidationService
  class << self
    # Consolidate time clockings for an issue/user/date
    # Calculates hours by summing time_hours from each clocking entry
    def consolidate_by_issue(issue_id, user_id, date = Date.today)
      time_clockings = TimeClocking.where(
        issue_id: issue_id,
        user_id: user_id,
        date: date,
        consolidated: [false, nil]
      ).where(status: [TimeClocking::STATUS_PENDING, nil])
      
      return nil if time_clockings.empty?
      
      # Calculate total hours by summing time_hours from all entries
      total_hours = time_clockings.sum(:time_hours).round(2)
      
      ActiveRecord::Base.transaction do
        time_entry = TimeEntry.create!(
          project_id: time_clockings.first.project_id,
          issue_id: issue_id,
          user_id: user_id,
          spent_on: date,
          hours: total_hours,
          activity_id: time_clockings.first.activity_id || default_activity_id,
          comments: "Consolidated from #{time_clockings.count} time clocking(s) - #{total_hours}h"
        )
        
        time_clockings.each do |tc|
          tc.update!(
            time_entry_id: time_entry.id,
            status: TimeClocking::STATUS_CONSOLIDATED,
            consolidated: true,
            consolidated_at: Time.current
          )
        end
        
        time_entry
      end
    rescue => e
      Rails.logger.error "Time clocking consolidation failed: #{e.message}"
      nil
    end
    
    # Auto-consolidate time clockings older than 4 hours
    def auto_consolidate_old_entries
      old_clockings = TimeClocking.needs_auto_consolidation
      
      return 0 if old_clockings.empty?
      
      # Group by issue/user/date
      groups = old_clockings.group_by { |tc| [tc.issue_id, tc.user_id, tc.date] }
      
      consolidated_count = 0
      groups.each do |(issue_id, user_id, date), clockings|
        total_hours = clockings.sum(&:time_hours).round(2)
        Rails.logger.info "Auto-consolidating #{clockings.count} time clockings for issue ##{issue_id}, user ##{user_id}, date #{date} (#{total_hours}h)"
        
        if consolidate_by_issue(issue_id, user_id, date)
          consolidated_count += clockings.count
        end
      end
      
      Rails.logger.info "Auto-consolidated #{consolidated_count} time clockings into #{groups.size} time entries"
      consolidated_count
    end
    
    private
    
    def default_activity_id
      TimeEntryActivity.first&.id || 9
    end
  end
end

