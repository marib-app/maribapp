import { placeholderImage } from '@/utils';
import React, { useState, useEffect } from 'react';
import { FaChevronLeft, FaChevronRight } from 'react-icons/fa';
import { IoMdClose } from 'react-icons/io';


const CustomLightBox = ({ lightboxOpen, handleCloseLightbox, currentImages, currentImageIndex, setCurrentImage }) => {

    const [isZoomed, setIsZoomed] = useState(false); // State for zoom
    const [zoomStyle, setZoomStyle] = useState({});


    useEffect(() => {
        setCurrentImage(currentImageIndex);
    }, [currentImageIndex]);

    useEffect(() => {
        // Disable scrolling when lightbox is open
        document.body.style.overflow = lightboxOpen ? 'hidden' : 'auto';

        const handleKeyDown = (e) => {
            if (e.key === 'Escape') {
                handleCloseLightbox();
            } else if (e.key === 'ArrowLeft') {
                goToPrevious();
            } else if (e.key === 'ArrowRight') {
                goToNext();
            }
        };

        if (lightboxOpen) {
            document.addEventListener('keydown', handleKeyDown);
        }

        // Cleanup scroll lock and event listener on component unmount
        return () => {
            document.body.style.overflow = 'auto';
            document.removeEventListener('keydown', handleKeyDown);
        };
    }, [lightboxOpen]);

    const goToPrevious = () => setCurrentImage((prevIndex) => (prevIndex - 1 + currentImages.length) % currentImages.length);
    const goToNext = () => setCurrentImage((prevIndex) => (prevIndex + 1) % currentImages.length);

    if (!lightboxOpen || !currentImages.length) return null;

    const currentImage = currentImages[currentImageIndex];
    const currentImageName = currentImages[currentImageIndex]?.alt;

    if (!currentImage) return null;

    // Handle clicks outside of the lightbox content
    const handleOverlayClick = (e) => {
        if (e.target === e.currentTarget) {
            handleCloseLightbox();
        }
    };

    const handleImageClick = (e) => {
        const rect = e.target.getBoundingClientRect(); // Get the image bounding rectangle
        const offsetX = e.clientX - rect.left; // Calculate click position relative to the image
        const offsetY = e.clientY - rect.top;

        setZoomStyle({
            transformOrigin: `${offsetX}px ${offsetY}px`, // Set transform origin
        });

        setIsZoomed((prevZoom) => !prevZoom); // Toggle zoom state
    };

    return (
        <div className="lightbox-overlay" onClick={handleOverlayClick}>
            <div className="lightbox-modal">
                <div className="lightbox-header">
                    {/* <span>{currentImageName}</span> */}
                    <button onClick={handleCloseLightbox} className="lightbox-close-button">
                        <IoMdClose size={24} />
                    </button>
                </div>
                <div className="lightbox-content">
                    <img src={currentImage} alt={`Image ${currentImageIndex + 1}`} className={`lightbox-image ${isZoomed ? 'zoomed' : ''}`} onError={placeholderImage} onClick={handleImageClick} style={isZoomed ? { ...zoomStyle } : {}} />
                    {currentImages && currentImages?.length > 1 &&
                        <>
                            <button onClick={goToPrevious} className="lightbox-prev-button">
                                <FaChevronLeft />
                            </button>
                            <button onClick={goToNext} className="lightbox-next-button">
                                <FaChevronRight />
                            </button>
                        </>
                    }
                </div>
            </div>
        </div>
    );
};

export default CustomLightBox;
