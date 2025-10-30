Redmine::Plugin.register :work_proof do
  name 'Work Proof Plugin'
  author 'Your Name'
  description 'This plugin adds a Work Proof feature to Redmine.'
  version '0.3.0'

  # Add menu item under project navigation
  menu :project_menu, 
       :work_proof, 
       { controller: 'work_proofs', action: 'index' }, 
       caption: 'Work Proof', 
       param: :project_id,
       active: Proc.new { |context| context[:controller].controller_name == 'work_proofs' }
  
  # Register custom permissions for Work Proof
  project_module :work_proof do
    permission :view_work_proof, { work_proofs: [:index], work_proofs_api: [:index, :show] }, public: false
    permission :view_self_work_proof, { work_proofs: [:index], work_proofs_api: [:index, :show] }, public: false
    permission :manage_work_proof, { work_proofs_api: [:create, :update, :destroy] }, public: false
  end
end
