class WorkProofConsolidationService
  class << self
    # Consolidate work proofs for an issue/user/date
    # Calculates hours by counting work proofs (each = interval minutes)
    def consolidate_by_issue(issue_id, user_id, date = Date.today, interval_minutes = 10)
      work_proofs = WorkProof.where(
        issue_id: issue_id,
        user_id: user_id,
        date: date,
        consolidated: [false, nil]
      ).where(status: [WorkProof::STATUS_PENDING, nil])
      
      return nil if work_proofs.empty?
      
      # Calculate total hours: count * interval / 60
      total_hours = (work_proofs.count * interval_minutes / 60.0).round(2)
      
      ActiveRecord::Base.transaction do
        time_entry = TimeEntry.create!(
          project_id: work_proofs.first.project_id,
          issue_id: issue_id,
          user_id: user_id,
          spent_on: date,
          hours: total_hours,
          activity_id: work_proofs.first.activity_id || default_activity_id,
          comments: "Consolidated from #{work_proofs.count} work proof(s) - #{total_hours}h"
        )
        
        work_proofs.each do |wp|
          wp.update!(
            time_entry_id: time_entry.id,
            status: WorkProof::STATUS_CONSOLIDATED,
            consolidated: true,
            consolidated_at: Time.current
          )
        end
        
        time_entry
      end
    rescue => e
      Rails.logger.error "Batch consolidation failed: #{e.message}"
      nil
    end
    
    # Auto-consolidate work proofs older than 4 hours
    # Groups by issue/user/date and consolidates each group
    def auto_consolidate_old_entries(interval_minutes = 10)
      # Find work proofs that need consolidation
      old_proofs = WorkProof.needs_auto_consolidation
      
      return 0 if old_proofs.empty?
      
      # Group by issue/user/date
      groups = old_proofs.group_by { |wp| [wp.issue_id, wp.user_id, wp.date] }
      
      consolidated_count = 0
      groups.each do |(issue_id, user_id, date), proofs|
        Rails.logger.info "Auto-consolidating #{proofs.count} work proofs for issue ##{issue_id}, user ##{user_id}, date #{date}"
        
        if consolidate_by_issue(issue_id, user_id, date, interval_minutes)
          consolidated_count += proofs.count
        end
      end
      
      Rails.logger.info "Auto-consolidated #{consolidated_count} work proofs into #{groups.size} time entries"
      consolidated_count
    end
    
    private
    
    def default_activity_id
      TimeEntryActivity.first&.id || 9 # 9 is typically "Development" in Redmine
    end
  end
end

