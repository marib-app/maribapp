import Image from "next/image"
import { Rate } from "antd"
import { formatDate, placeholderImage } from "@/utils"
import { useEffect, useRef, useState } from "react";
import { useSelector } from "react-redux";
import { settingsData } from "@/redux/reuducer/settingSlice";



const SellerReviewCard = ({ rating }) => {

    const systemSettings = useSelector(settingsData)
    const placeholder_image = systemSettings?.data?.placeholder_image
    const [isExpanded, setIsExpanded] = useState(false);
    const [isOverflowing, setIsOverflowing] = useState(false);
    const contentRef = useRef(null);  // Reference to the content


    const checkOverflow = () => {
        const content = contentRef.current;
        if (content) {
            setIsOverflowing(content.scrollHeight > content.clientHeight);
        }
    };

    useEffect(() => {
        // Initial check for overflow when the component is mounted
        checkOverflow();
        // Event listener for window resize to recalculate on screen resize
        const handleResize = () => {
            checkOverflow();
        };
        window.addEventListener('resize', handleResize);
        // Cleanup event listener on unmount
        return () => {
            window.removeEventListener('resize', handleResize);
        };
    }, [rating]);

    // Function to toggle between showing more or less content
    const toggleExpand = () => {
        setIsExpanded(!isExpanded);
    };




    return (
        <>
            <div className="reviewCardWrapper">
                <div className="reviewCard">
                    <div className="reviewerDetails">
                        <Image width={72} height={72} src={rating?.buyer?.profile || placeholder_image} className="reviewerImg" alt="reviewer image" onErrorCapture={placeholderImage} />
                        <div className="review_nameRating">
                            <p className="reviewerName">{rating?.buyer?.name}</p>
                            <div className="reviewStarTimeCont">
                                <div className="reviewStarsCont">
                                    <Rate disabled allowHalf value={rating?.ratings} className="reviewerStarRating reviewerStarRating" />
                                    <span className="reviewerRating">{rating?.ratings}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                    <span className="timeAgo">{formatDate(rating?.created_at)}</span>
                </div>
                <div className="horizontal_border">
                </div>
                <p className={`reviewContent ${isExpanded ? 'expanded' : 'collapsed'}`} ref={contentRef}>{rating?.review}</p>


                {isOverflowing && (  // Arbitrary length check to show 'See More' button if review is long
                    <button className="seeMoreLessBtn" onClick={toggleExpand}>
                        {isExpanded ? 'See Less' : 'See More'}
                    </button>
                )}
            </div>
        </>
    )
}

export default SellerReviewCard