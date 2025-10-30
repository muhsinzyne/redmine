namespace :work_proof do
  desc "Auto-consolidate work proofs older than 4 hours"
  task auto_consolidate: :environment do
    puts "Starting auto-consolidation of old work proofs..."
    count = WorkProofConsolidationService.auto_consolidate_old_entries
    puts "Consolidated #{count} work proofs"
  end
  
  desc "Show work proofs needing consolidation"
  task check_pending: :environment do
    work_proofs = WorkProof.needs_auto_consolidation
    puts "Found #{work_proofs.count} work proofs needing consolidation:"
    work_proofs.each do |wp|
      puts "  - WorkProof ##{wp.id}: #{wp.user_name} on #{wp.issue_subject} (#{wp.clock_duration}h)"
    end
  end
end

