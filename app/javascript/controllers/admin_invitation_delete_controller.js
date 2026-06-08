import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="admin-invitation-delete"
// Prevents invitation action buttons in collapsible headers from toggling sections.
export default class extends Controller {
  stopPropagation(event) {
    event.stopPropagation()
  }
}
