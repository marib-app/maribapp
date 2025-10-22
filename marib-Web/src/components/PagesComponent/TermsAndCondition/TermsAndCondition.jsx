'use client'
import React from 'react'
import BreadcrumbComponent from '@/components/Breadcrumb/BreadcrumbComponent'
import { store } from '@/redux/store'
import { t } from '@/utils'
import parse, { domToReact } from 'html-react-parser';
import Link from "next/link"

const TermsAndCondition = () => {

    const settingsData = store.getState().Settings.data
    const terms_conditions = settingsData?.data?.terms_conditions


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
            <BreadcrumbComponent title2={t('termsConditions')} />
            <div className='container'>
                {/* <div className="main_title">
                    <span>
                        {t('aboutUs')}
                    </span>
                </div> */}
                <div className="page_content">
                    {parse(terms_conditions || '', options)}
                </div>
            </div>
        </section>
    )
}

export default TermsAndCondition
