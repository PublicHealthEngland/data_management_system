require 'test_helper'

module Workflow
  # Tests behaviour of the ProjectState class.
  class ProjectStateTest < ActiveSupport::TestCase
    def setup
      @project_state = workflow_project_states(:one)
      @project = create_project(
        team: teams(:team_one),
        project_type: project_types(:application),
        project_purpose: 'previous state test',
        assigned_user: users(:application_manager_one)
      )
    end

    test 'should belong to a project' do
      assert_instance_of Project, @project_state.project
    end

    test 'should belong to a state' do
      assert_instance_of State, @project_state.state
    end

    test 'should optionally belong to a user' do
      assert_instance_of User, @project_state.user
    end

    test 'should be invalid without a project' do
      @project_state.stubs(ensure_state_is_transitionable: true)

      @project_state.project = nil
      @project_state.valid?
      assert_includes @project_state.errors.details[:project], error: :blank
    end

    test 'should be invalid without a state' do
      @project_state.stubs(ensure_state_is_transitionable: true)

      @project_state.state = nil
      @project_state.valid?
      assert_includes @project_state.errors.details[:state], error: :blank
    end

    test 'should not be invalid without a user' do
      @project_state.stubs(ensure_state_is_transitionable: true)

      @project_state.user = nil
      @project_state.valid?
      refute_includes @project_state.errors.details[:user], error: :blank
    end

    test 'should be invalid if state is not reachable' do
      project       = projects(:dummy_project)
      current_state = workflow_states(:draft)
      project_state = ProjectState.new(project: project, state: workflow_states(:step_one))

      project.stubs(current_state: current_state)

      project.stubs(transitionable_states: current_state.transitionable_states.none)
      project_state.valid?
      assert_includes project_state.errors.details[:state], error: :invalid

      project.stubs(transitionable_states: current_state.transitionable_states)
      project_state.valid?
      refute_includes project_state.errors.details[:state], error: :invalid
    end

    test 'closing application updates closure date and reason' do
      @project.transition_to!(workflow_states(:draft))
      @project.reload
      assert_changes -> { @project.closure_date } do
        @project.transition_to!(workflow_states(:rejected))
      end
    end

    test 'reopening application removes closure date and reason' do
      @project.transition_to!(workflow_states(:draft))
      @project.transition_to!(workflow_states(:submitted))
      @project.transition_to!(workflow_states(:rejected))
      @project.update(closure_date: Date.current, closure_reason_id: Lookups::ClosureReason.first.id)
      assert_changes -> { @project.closure_date } do
        assert_changes -> { @project.closure_reason_id } do
          @project.transition_to!(workflow_states(:submitted))
        end
      end
    end
  end
end
