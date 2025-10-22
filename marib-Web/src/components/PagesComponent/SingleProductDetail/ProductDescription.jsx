'use client'
import React, { useState, useRef } from 'react';
import parse, { domToReact } from 'html-react-parser';
import Link from 'next/link';


function ProductDescription({ productData, t }) {

    const [showFullDescription, setShowFullDescription] = useState(false);
    const descriptionRef = useRef(null);

    const toggleDescription = () => {
        setShowFullDescription(!showFullDescription);
        const descriptionBody = descriptionRef.current;
        if (descriptionBody) {
            descriptionBody.classList.toggle('show-full-description');
        }
    };

    const getDescriptionHeight = () => {
        return showFullDescription ? '100%' : '300px'; // Adjust height as needed
    };

    const maxLength = 350; // Maximum length for truncated description

    const fullDescription = productData?.description?.replace(/\n/g, '<br />');

    const truncatedDescription =
        fullDescription?.length > maxLength && !showFullDescription
            ? `${fullDescription.slice(0, maxLength)}...`
            : fullDescription;


    const options = {
        replace: (domNode) => {
            // Check if the node is an anchor tag <a>
            if (domNode.name === 'a' && domNode.attribs && domNode.attribs.href) {

                const { href, ...otherAttribs } = domNode.attribs;

                return (
                    <Link href={href} {...otherAttribs} className="blog_link">
                        {domToReact(domNode.children)}
                    </Link>
                );
            }
        },
    };


    return (
        <div className="description_card card">
            {fullDescription && (
                <>
                    <div className="card-header">
                        <span>{t('description')}</span>
                    </div>
                    <div
                        className="card-body"
                        style={{ maxHeight: getDescriptionHeight(), whiteSpace: 'pre-line' }}
                        ref={descriptionRef}
                    >
                        {parse(truncatedDescription || '', options)}
                    </div>
                    {fullDescription.length > maxLength && (
                        <div className="card-footer">
                            <button onClick={toggleDescription}>
                                {showFullDescription ? t('seeLess') : t('seeMore')}
                            </button>
                        </div>
                    )}
                </>
            )}
        </div>
    );
}
export default ProductDescription;