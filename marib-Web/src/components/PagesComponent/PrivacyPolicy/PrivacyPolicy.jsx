'use client'
import React from 'react'
import BreadcrumbComponent from '@/components/Breadcrumb/BreadcrumbComponent'
import { store } from '@/redux/store'
import { t } from '@/utils'
import parse, { domToReact } from 'html-react-parser';
import Link from "next/link"

const PrivacyPolicy = () => {

    const settingsData = store.getState().Settings.data
    const privacy = settingsData?.data?.privacy_policy


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
        <section className='aboutus'>
            <BreadcrumbComponent title2={t('privacyPolicy')} />
            <div className='container'>
                {/* <div className="main_title">
                    <span>
                        {t('aboutUs')}
                    </span>
                </div> */}
                <div className="page_content">
                    {parse(privacy || '', options)}
                </div>
            </div>
        </section>
    )
}

export default PrivacyPolicy
