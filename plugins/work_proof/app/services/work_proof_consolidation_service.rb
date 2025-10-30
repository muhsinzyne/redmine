class WorkProofConsolidationService
  class << self
    # Consolidate a single work proof to time_entry
    def consolidate_work_proof(work_proof)
      return nil if work_proof.consolidated?
      return nil unless work_proof.clocked_out?
      
      ActiveRecord::Base.transaction do
        time_entry = TimeEntry.create!(
          project_id: work_proof.project_id,
          issue_id: work_proof.issue_id,
          user_id: work_proof.user_id,
          spent_on: work_proof.date,
          hours: work_proof.work_hours || work_proof.clock_duration,
          activity_id: work_proof.activity_id || default_activity_id,
          comments: generate_comments(work_proof)
        )
        
        work_proof.update!(
          time_entry_id: time_entry.id,
          status: WorkProof::STATUS_CONSOLIDATED,
          consolidated: true,
          consolidated_at: Time.current
        )
        
        time_entry
      end
    rescue => e
      Rails.logger.error "Consolidation failed for work_proof #{work_proof.id}: #{e.message}"
      nil
    end
    
    # Consolidate all clocked-out work proofs for an issue/user/date
    def consolidate_by_issue(issue_id, user_id, date = Date.today)
      work_proofs = WorkProof.where(
        issue_id: issue_id,
        user_id: user_id,
        date: date,
        status: [WorkProof::STATUS_CLOCKED_OUT, WorkProof::STATUS_CALCULATED],
        consolidated: false
      )
      
      return nil if work_proofs.empty?
      
      total_hours = work_proofs.sum(:work_hours)
      
      ActiveRecord::Base.transaction do
        time_entry = TimeEntry.create!(
          project_id: work_proofs.first.project_id,
          issue_id: issue_id,
          user_id: user_id,
          spent_on: date,
          hours: total_hours,
          activity_id: work_proofs.first.activity_id || default_activity_id,
          comments: "Consolidated from #{work_proofs.count} work proof(s)"
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
    def auto_consolidate_old_entries
      work_proofs = WorkProof.needs_auto_consolidation
      
      consolidated_count = 0
      work_proofs.find_each do |work_proof|
        # Auto calculate hours if not clocked out
        if work_proof.status == WorkProof::STATUS_PENDING || work_proof.status == WorkProof::STATUS_CLOCKED_IN
          work_proof.clocked_out_at = Time.current
          work_proof.work_hours = work_proof.clock_duration
          work_proof.status = WorkProof::STATUS_CALCULATED
          work_proof.save!
        end
        
        # Consolidate to time entry
        if consolidate_work_proof(work_proof)
          consolidated_count += 1
        end
      end
      
      Rails.logger.info "Auto-consolidated #{consolidated_count} work proofs"
      consolidated_count
    end
    
    private
    
    def default_activity_id
      TimeEntryActivity.first&.id || 9 # 9 is typically "Development" in Redmine
    end
    
    def generate_comments(work_proof)
      comments = "Work proof ##{work_proof.id}"
      comments += " - #{work_proof.description}" if work_proof.description.present?
      comments
    end
  end
end

