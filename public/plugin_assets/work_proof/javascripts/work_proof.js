function openModal(imageUrl, time) {
    const modal = document.getElementById('custom-modal');
    const modalImage = document.getElementById('modal-image');
  
    modalImage.src = imageUrl;
    modal.style.display = 'block';
  }
  
  function closeModal() {
    const modal = document.getElementById('custom-modal');
    modal.style.display = 'none';
  }
  
  // Close the modal if the user clicks outside the image
  window.onclick = function (event) {
    const modal = document.getElementById('custom-modal');
    if (event.target === modal) {
      closeModal();
    }
  };
  